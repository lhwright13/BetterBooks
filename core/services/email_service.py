import os
import logging
import secrets
import asyncio
from typing import Dict, Any, Optional
from datetime import datetime, timedelta
from enum import Enum
from dataclasses import dataclass

import sendgrid
from sendgrid.helpers.mail import Mail, Email, To
import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)


class EmailProvider(Enum):
    SENDGRID = "sendgrid"
    AWS_SES = "aws_ses"
    SMTP = "smtp"


class EmailTemplate(Enum):
    VERIFICATION = "email_verification"
    WELCOME = "welcome"
    PASSWORD_RESET = "password_reset"
    SUBSCRIPTION_CONFIRMATION = "subscription_confirmation"
    ACCOUNT_SUSPENDED = "account_suspended"


@dataclass
class EmailConfig:
    provider: EmailProvider
    from_email: str
    from_name: str
    templates: Dict[EmailTemplate, str]
    max_retries: int = 3
    retry_delay: int = 5  # seconds


class EmailServiceError(Exception):
    pass


class EmailService:

    def __init__(self, config: Optional[EmailConfig] = None):
        self.config = config or self._load_config()
        self.client = self._init_client()
        self.templates = {
            EmailTemplate.VERIFICATION: {
                "subject": "Verify your EchoWright account",
                "template_id": os.getenv("SENDGRID_VERIFICATION_TEMPLATE_ID", "d-verification"),
            },
            EmailTemplate.WELCOME: {
                "subject": "Welcome to EchoWright!",
                "template_id": os.getenv("SENDGRID_WELCOME_TEMPLATE_ID", "d-welcome"),
            },
            EmailTemplate.PASSWORD_RESET: {
                "subject": "Reset your EchoWright password",
                "template_id": os.getenv("SENDGRID_PASSWORD_RESET_TEMPLATE_ID", "d-password-reset"),
            },
            EmailTemplate.SUBSCRIPTION_CONFIRMATION: {
                "subject": "Subscription confirmed - Welcome to Premium!",
                "template_id": os.getenv("SENDGRID_SUBSCRIPTION_TEMPLATE_ID", "d-subscription"),
            },
            EmailTemplate.ACCOUNT_SUSPENDED: {
                "subject": "Important: Account status update",
                "template_id": os.getenv("SENDGRID_SUSPENDED_TEMPLATE_ID", "d-suspended"),
            }
        }
        
        logger.info(f"Email service initialized with provider: {self.config.provider.value}")

    def _load_config(self) -> EmailConfig:
        provider_name = os.getenv("EMAIL_PROVIDER", "sendgrid").lower()
        try:
            provider = EmailProvider(provider_name)
        except ValueError:
            logger.warning(f"Unknown email provider: {provider_name}, defaulting to SendGrid")
            provider = EmailProvider.SENDGRID

        return EmailConfig(
            provider=provider,
            from_email=os.getenv("FROM_EMAIL", "noreply@echowright.com"),
            from_name=os.getenv("FROM_NAME", "EchoWright"),
            templates={},
            max_retries=int(os.getenv("EMAIL_MAX_RETRIES", "3")),
            retry_delay=int(os.getenv("EMAIL_RETRY_DELAY", "5"))
        )

    def _init_client(self):
        if self.config.provider == EmailProvider.SENDGRID:
            api_key = os.getenv("SENDGRID_API_KEY")
            if not api_key:
                raise EmailServiceError("SENDGRID_API_KEY environment variable is required")
            return sendgrid.SendGridAPIClient(api_key=api_key)
        
        elif self.config.provider == EmailProvider.AWS_SES:
            return boto3.client(
                'ses',
                region_name=os.getenv("AWS_REGION", "us-east-1"),
                aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID"),
                aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY")
            )
        
        else:
            raise EmailServiceError(f"Unsupported email provider: {self.config.provider}")

    def generate_verification_token(self) -> str:
        return secrets.token_urlsafe(32)

    def generate_reset_token(self) -> str:
        return secrets.token_urlsafe(32)

    async def send_verification_email(
        self,
        email: str,
        verification_token: str,
        user_name: Optional[str] = None
    ) -> bool:
        frontend_url = os.getenv("FRONTEND_URL", "https://app.echowright.com")
        verification_url = f"{frontend_url}/verify-email?token={verification_token}"
        
        template_data = {
            "user_name": user_name or "User",
            "verification_url": verification_url,
            "verification_token": verification_token,
            "app_name": "EchoWright",
            "support_email": "support@echowright.com"
        }
        
        return await self._send_templated_email(
            email=email,
            template=EmailTemplate.VERIFICATION,
            template_data=template_data
        )

    async def send_welcome_email(
        self,
        email: str,
        user_name: str,
        subscription_plan: Optional[str] = None
    ) -> bool:
        template_data = {
            "user_name": user_name,
            "app_name": "EchoWright",
            "subscription_plan": subscription_plan or "Free",
            "app_url": os.getenv("FRONTEND_URL", "https://app.echowright.com"),
            "support_email": "support@echowright.com",
            "getting_started_url": f"{os.getenv('FRONTEND_URL', 'https://app.echowright.com')}/getting-started"
        }
        
        return await self._send_templated_email(
            email=email,
            template=EmailTemplate.WELCOME,
            template_data=template_data
        )

    async def send_password_reset_email(
        self,
        email: str,
        reset_token: str,
        user_name: Optional[str] = None
    ) -> bool:
        frontend_url = os.getenv("FRONTEND_URL", "https://app.echowright.com")
        reset_url = f"{frontend_url}/reset-password?token={reset_token}"
        expires_at = datetime.utcnow() + timedelta(hours=1)
        
        template_data = {
            "user_name": user_name or "User",
            "reset_url": reset_url,
            "reset_token": reset_token,
            "expires_at": expires_at.strftime("%B %d, %Y at %I:%M %p UTC"),
            "app_name": "EchoWright",
            "support_email": "support@echowright.com"
        }
        
        return await self._send_templated_email(
            email=email,
            template=EmailTemplate.PASSWORD_RESET,
            template_data=template_data
        )

    async def _send_templated_email(
        self,
        email: str,
        template: EmailTemplate,
        template_data: Dict[str, Any]
    ) -> bool:
        for attempt in range(self.config.max_retries):
            try:
                if self.config.provider == EmailProvider.SENDGRID:
                    success = await self._send_sendgrid_email(email, template, template_data)
                elif self.config.provider == EmailProvider.AWS_SES:
                    success = await self._send_ses_email(email, template, template_data)
                else:
                    raise EmailServiceError(f"Unsupported provider: {self.config.provider}")
                
                if success:
                    logger.info(f"Email sent successfully: {template.value} to {email}")
                    return True
                    
            except Exception as e:
                logger.warning(f"Email attempt {attempt + 1} failed: {e}")
                if attempt < self.config.max_retries - 1:
                    await asyncio.sleep(self.config.retry_delay * (2 ** attempt))
                else:
                    logger.error(f"All email attempts failed for {email}: {e}")
        
        return False

    async def _send_sendgrid_email(
        self,
        email: str,
        template: EmailTemplate,
        template_data: Dict[str, Any]
    ) -> bool:
        try:
            template_config = self.templates[template]
            message = Mail(
                from_email=Email(self.config.from_email, self.config.from_name),
                to_emails=To(email),
                subject=template_config["subject"]
            )
            message.dynamic_template_data = template_data
            message.template_id = template_config["template_id"]
            
            response = await asyncio.to_thread(self.client.send, message)
            return response.status_code in [200, 202]
            
        except Exception as e:
            logger.error(f"SendGrid error: {e}")
            return False

    async def _send_ses_email(
        self,
        email: str,
        template: EmailTemplate,
        template_data: Dict[str, Any]
    ) -> bool:
        try:
            template_config = self.templates[template]
            response = await asyncio.to_thread(
                self.client.send_templated_email,
                Source=f"{self.config.from_name} <{self.config.from_email}>",
                Destination={'ToAddresses': [email]},
                Template=template_config["template_id"],
                TemplateData=str(template_data)
            )
            
            return response['ResponseMetadata']['HTTPStatusCode'] == 200
            
        except ClientError as e:
            logger.error(f"SES error: {e}")
            return False


_email_service: Optional[EmailService] = None


def get_email_service() -> EmailService:
    global _email_service
    if _email_service is None:
        _email_service = EmailService()
    return _email_service