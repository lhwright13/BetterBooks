"""
Email Service for EchoWright Authentication

Provides email functionality for user authentication including:
- Email verification
- Password reset
- Welcome emails
- Account notifications

Supports multiple email providers (SendGrid, AWS SES) with fallback capabilities.
Includes retry logic, error handling, and template management.
"""

import os
import logging
import secrets
import asyncio
from typing import Dict, Any, Optional, List
from datetime import datetime, timedelta
from enum import Enum
from dataclasses import dataclass

# Email providers
import sendgrid
from sendgrid.helpers.mail import Mail, Email, To, Content
import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)


class EmailProvider(Enum):
    """Supported email providers"""
    SENDGRID = "sendgrid"
    AWS_SES = "aws_ses"
    SMTP = "smtp"


class EmailTemplate(Enum):
    """Available email templates"""
    VERIFICATION = "email_verification"
    WELCOME = "welcome"
    PASSWORD_RESET = "password_reset"
    SUBSCRIPTION_CONFIRMATION = "subscription_confirmation"
    ACCOUNT_SUSPENDED = "account_suspended"


@dataclass
class EmailConfig:
    """Email service configuration"""
    provider: EmailProvider
    from_email: str
    from_name: str
    templates: Dict[EmailTemplate, str]
    max_retries: int = 3
    retry_delay: int = 5  # seconds


class EmailServiceError(Exception):
    """Custom exception for email service errors"""
    pass


class EmailService:
    """
    Email service with multiple provider support and template management
    
    Features:
    - Multiple email providers (SendGrid, AWS SES)
    - Template management with dynamic content
    - Retry logic with exponential backoff
    - Async email sending
    - Token generation for verification
    - Rate limiting and error handling
    """
    
    def __init__(self, config: Optional[EmailConfig] = None):
        """Initialize email service with configuration"""
        self.config = config or self._load_config()
        self.client = self._init_client()
        
        # Template configurations
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
        """Load email configuration from environment variables"""
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
            templates={},  # Will be populated from environment or defaults
            max_retries=int(os.getenv("EMAIL_MAX_RETRIES", "3")),
            retry_delay=int(os.getenv("EMAIL_RETRY_DELAY", "5"))
        )

    def _init_client(self):
        """Initialize email client based on provider"""
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
        """Generate a secure verification token"""
        return secrets.token_urlsafe(32)

    def generate_reset_token(self) -> str:
        """Generate a secure password reset token"""
        return secrets.token_urlsafe(32)

    async def send_verification_email(
        self, 
        email: str, 
        verification_token: str, 
        user_name: Optional[str] = None
    ) -> bool:
        """
        Send email verification email
        
        Args:
            email: Recipient email address
            verification_token: Verification token for the link
            user_name: Optional user name for personalization
            
        Returns:
            bool: True if email sent successfully
        """
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
        """
        Send welcome email to new user
        
        Args:
            email: Recipient email address
            user_name: User's display name
            subscription_plan: Optional subscription plan info
            
        Returns:
            bool: True if email sent successfully
        """
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
        """
        Send password reset email
        
        Args:
            email: Recipient email address
            reset_token: Password reset token
            user_name: Optional user name for personalization
            
        Returns:
            bool: True if email sent successfully
        """
        frontend_url = os.getenv("FRONTEND_URL", "https://app.echowright.com")
        reset_url = f"{frontend_url}/reset-password?token={reset_token}"
        
        # Token expires in 1 hour
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

    async def send_subscription_confirmation_email(
        self, 
        email: str, 
        user_name: str,
        plan_name: str,
        amount: str,
        billing_cycle: str
    ) -> bool:
        """
        Send subscription confirmation email
        
        Args:
            email: Recipient email address
            user_name: User's display name
            plan_name: Subscription plan name
            amount: Subscription amount
            billing_cycle: Billing cycle (monthly/annual)
            
        Returns:
            bool: True if email sent successfully
        """
        template_data = {
            "user_name": user_name,
            "plan_name": plan_name,
            "amount": amount,
            "billing_cycle": billing_cycle,
            "app_name": "EchoWright",
            "app_url": os.getenv("FRONTEND_URL", "https://app.echowright.com"),
            "manage_subscription_url": f"{os.getenv('FRONTEND_URL', 'https://app.echowright.com')}/account/subscription",
            "support_email": "support@echowright.com"
        }
        
        return await self._send_templated_email(
            email=email,
            template=EmailTemplate.SUBSCRIPTION_CONFIRMATION,
            template_data=template_data
        )

    async def _send_templated_email(
        self,
        email: str,
        template: EmailTemplate,
        template_data: Dict[str, Any]
    ) -> bool:
        """
        Send templated email with retry logic
        
        Args:
            email: Recipient email address
            template: Email template to use
            template_data: Data to populate template
            
        Returns:
            bool: True if email sent successfully
        """
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
        """Send email using SendGrid"""
        try:
            template_config = self.templates[template]
            
            message = Mail(
                from_email=Email(self.config.from_email, self.config.from_name),
                to_emails=To(email),
                subject=template_config["subject"]
            )
            
            # Add template data as dynamic template data
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
        """Send email using AWS SES"""
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

    async def verify_email_deliverability(self, email: str) -> bool:
        """
        Verify if email address is deliverable (basic validation)
        
        Args:
            email: Email address to verify
            
        Returns:
            bool: True if email appears deliverable
        """
        # Basic email format validation
        import re
        pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if not re.match(pattern, email):
            return False
        
        # Additional checks can be added here (MX record lookup, etc.)
        return True

    async def get_email_status(self, message_id: str) -> Optional[Dict[str, Any]]:
        """
        Get delivery status of sent email (if supported by provider)
        
        Args:
            message_id: Email message ID
            
        Returns:
            Dict with status information or None
        """
        # Implementation depends on provider capabilities
        # This is a placeholder for future enhancement
        return None


# Global email service instance
_email_service: Optional[EmailService] = None


def get_email_service() -> EmailService:
    """Get global email service instance"""
    global _email_service
    if _email_service is None:
        _email_service = EmailService()
    return _email_service


# Convenience functions for common email operations
async def send_verification_email(email: str, token: str, user_name: Optional[str] = None) -> bool:
    """Send verification email"""
    service = get_email_service()
    return await service.send_verification_email(email, token, user_name)


async def send_welcome_email(email: str, user_name: str, subscription_plan: Optional[str] = None) -> bool:
    """Send welcome email"""
    service = get_email_service()
    return await service.send_welcome_email(email, user_name, subscription_plan)


async def send_password_reset_email(email: str, token: str, user_name: Optional[str] = None) -> bool:
    """Send password reset email"""
    service = get_email_service()
    return await service.send_password_reset_email(email, token, user_name)


async def generate_and_send_verification_email(email: str, user_name: Optional[str] = None) -> str:
    """Generate verification token and send email"""
    service = get_email_service()
    token = service.generate_verification_token()
    await service.send_verification_email(email, token, user_name)
    return token


async def generate_and_send_reset_email(email: str, user_name: Optional[str] = None) -> str:
    """Generate reset token and send email"""
    service = get_email_service()
    token = service.generate_reset_token()
    await service.send_password_reset_email(email, token, user_name)
    return token