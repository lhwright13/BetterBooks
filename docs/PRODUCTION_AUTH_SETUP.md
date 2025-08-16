# Production Authentication & Payment Setup Guide

This guide walks through setting up the new BetterBooks authentication and payment system for production deployment.

## 🎯 Overview

The new system provides:
- ✅ **Apple App Store compliant** iOS payments via StoreKit 2
- ✅ **Web payments** through Stripe
- ✅ **Multi-provider authentication** (Apple, Google, Email)
- ✅ **Proper identity separation** with PostgreSQL
- ✅ **Entitlements management** for feature gating
- ✅ **GDPR compliance** with account deletion

## 📋 Prerequisites Checklist

### Required Accounts
- [ ] **Supabase Project** (replaces Azure AD B2C)
- [ ] **Apple Developer Account** ($99/year)
- [ ] **Stripe Account** (for web payments)
- [ ] **PostgreSQL Database** (production)

### Required Configurations
- [ ] App Store Connect app configured
- [ ] Supabase authentication providers enabled
- [ ] Stripe products and prices created
- [ ] Database schema migrated

## 🔧 Step 1: Database Setup

### 1.1 Run Migration

```bash
# Apply the new schema
psql -h your-db-host -U your-user -d betterbooks < core/database/migrations/V005_20250114_user_identity_system.sql
```

### 1.2 Verify Tables Created

```sql
-- Check that all tables exist
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('users', 'identities', 'subscriptions', 'entitlements', 'apple_receipts', 'stripe_events');
```

## 🔐 Step 2: Supabase Configuration

### 2.1 Create Supabase Project

1. Go to [supabase.com](https://supabase.com)
2. Create new project: `betterbooks-production`
3. Note the project URL and keys

### 2.2 Enable Authentication Providers

In Supabase Dashboard → Authentication → Providers:

**Apple Provider:**
```
Service ID: com.betterbooks.app
Team ID: [Your Apple Team ID]
Key ID: [From Apple Developer]
Private Key: [Download from Apple Developer]
```

**Google Provider:**
```
Client ID: [From Google Cloud Console]
Client Secret: [From Google Cloud Console]
```

### 2.3 Configure Environment Variables

```bash
# Add to your .env file:
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

## 🍎 Step 3: Apple App Store Setup

### 3.1 App Store Connect Configuration

1. **Create App** in App Store Connect
2. **Bundle ID**: `com.betterbooks.app`
3. **Enable In-App Purchases**

### 3.2 Create Subscription Products

Create these product IDs in App Store Connect:

```
Monthly Premium: com.betterbooks.monthly
- Price: $9.99/month
- Features: Premium access, unlimited books

Yearly Premium: com.betterbooks.yearly  
- Price: $99.99/year
- Features: Premium access, unlimited books

Family Plan: com.betterbooks.family
- Price: $19.99/month
- Features: Premium access, family sharing, unlimited books
```

### 3.3 App Store Server API Configuration

1. **Create Private Key** in App Store Connect → Users and Access → Keys
2. **Note Key ID and Issuer ID**
3. **Download Private Key** (.p8 file)

### 3.4 Environment Variables

```bash
# Add to your .env file:
APPLE_BUNDLE_ID=com.betterbooks.app
APPLE_KEY_ID=your-key-id
APPLE_ISSUER_ID=your-issuer-id
APPLE_PRIVATE_KEY=your-private-key-content
```

## 💳 Step 4: Stripe Configuration

### 4.1 Create Stripe Products

In Stripe Dashboard → Products, create:

**Monthly Premium**
```
Product ID: prod_monthly_premium
Price: $9.99/month (price_monthly_999)
```

**Yearly Premium**
```
Product ID: prod_yearly_premium  
Price: $99.99/year (price_yearly_9999)
```

**Family Plan**
```
Product ID: prod_family_plan
Price: $19.99/month (price_family_1999)
```

### 4.2 Configure Webhooks

1. **Webhook URL**: `https://api.betterbooks.com/webhooks/stripe`
2. **Events to Send**:
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `invoice.paid`
   - `invoice.payment_failed`

### 4.3 Environment Variables

```bash
# Add to your .env file:
STRIPE_SECRET_KEY=sk_live_...
STRIPE_PUBLISHABLE_KEY=pk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...
WEB_APP_URL=https://betterbooks.com
```

## 🚀 Step 5: Deployment Configuration

### 5.1 Complete Environment Variables

```bash
# Authentication
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# Apple App Store
APPLE_BUNDLE_ID=com.betterbooks.app
APPLE_KEY_ID=your-key-id
APPLE_ISSUER_ID=your-issuer-id
APPLE_PRIVATE_KEY=your-private-key-content

# Stripe
STRIPE_SECRET_KEY=sk_live_...
STRIPE_PUBLISHABLE_KEY=pk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...

# Database
DATABASE_URL=postgresql://user:pass@host:5432/betterbooks

# Application
WEB_APP_URL=https://betterbooks.com
DEFAULT_ADMIN_PASSWORD=SecurePassword123!
```

### 5.2 Update Product Configurations

In `core/database/models/user.py`, update:

```python
class SubscriptionPlan:
    # App Store product IDs (match App Store Connect)
    IOS_MONTHLY = "com.betterbooks.monthly"
    IOS_YEARLY = "com.betterbooks.yearly" 
    IOS_FAMILY = "com.betterbooks.family"
    
    # Stripe price IDs (match Stripe Dashboard)
    STRIPE_MONTHLY = "price_monthly_999"
    STRIPE_YEARLY = "price_yearly_9999"
    STRIPE_FAMILY = "price_family_1999"
```

## 📱 Step 6: iOS App Configuration

### 6.1 Update iOS Configuration

In `ios/Runner/Info.plist`:

```xml
<!-- Apple Sign In -->
<key>CFBundleIdentifier</key>
<string>com.betterbooks.app</string>

<!-- StoreKit Configuration -->
<key>SKStoreKitConfigurationFile</key>
<string>Configuration</string>
```

### 6.2 Add StoreKit Configuration File

Create `ios/Configuration.storekit`:

```json
{
  "identifier" : "configuration",
  "nonRenewingSubscriptions" : [],
  "products" : [],
  "settings" : {},
  "subscriptionGroups" : [
    {
      "id" : "premium_subscriptions",
      "localizations" : [],
      "name" : "Premium Subscriptions",
      "subscriptions" : [
        {
          "adHocOffers" : [],
          "codeOffers" : [],
          "displayPrice" : "9.99",
          "familyShareable" : false,
          "id" : "com.betterbooks.monthly",
          "introductoryOffer" : null,
          "localizations" : [
            {
              "description" : "Monthly premium access",
              "displayName" : "Monthly Premium",
              "locale" : "en_US"
            }
          ],
          "productId" : "com.betterbooks.monthly",
          "recurringSubscriptionPeriod" : "P1M",
          "referenceName" : "Monthly Premium",
          "subscriptionGroupId" : "premium_subscriptions",
          "type" : "RecurringSubscription"
        }
      ]
    }
  ],
  "version" : {
    "major" : 1,
    "minor" : 0
  }
}
```

## 🧪 Step 7: Testing

### 7.1 Test Authentication

```bash
# Test Apple Sign In
curl -X POST "https://api.betterbooks.com/auth/apple" \
  -H "Content-Type: application/json" \
  -d '{
    "id_token": "test-token",
    "nonce": "test-nonce"
  }'

# Test Google Sign In  
curl -X POST "https://api.betterbooks.com/auth/google" \
  -H "Content-Type: application/json" \
  -d '{
    "id_token": "test-token"
  }'
```

### 7.2 Test Entitlements

```bash
# Get user entitlements
curl -X GET "https://api.betterbooks.com/me/entitlements" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### 7.3 Test iOS Sandbox

1. **Create Sandbox Test User** in App Store Connect
2. **Sign in with test user** in iOS Settings
3. **Test subscription purchase** in your app
4. **Verify webhook reception** in your logs

### 7.4 Test Stripe

```bash
# Create test checkout session
curl -X POST "https://api.betterbooks.com/payments/stripe/checkout" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "price_id": "price_monthly_999"
  }'
```

## 🔒 Step 8: Security Checklist

### 8.1 Environment Security
- [ ] All API keys stored in environment variables (not code)
- [ ] Database passwords rotated and secure
- [ ] HTTPS enabled on all endpoints
- [ ] CORS configured properly

### 8.2 Apple Compliance
- [ ] Sign in with Apple button prominent (Guideline 4.8)
- [ ] Restore Purchases button implemented (required)
- [ ] Account deletion in-app (Guideline 5.1.1)
- [ ] Subscription management links to iOS Settings
- [ ] External links only in US storefront (3.1.3a)

### 8.3 Data Privacy
- [ ] GDPR-compliant data deletion
- [ ] Privacy policy updated
- [ ] User consent for data processing
- [ ] Audit logging enabled

## 🚨 Troubleshooting

### Common Issues

**"Apple sign in failed"**
- Check Apple Developer certificates
- Verify bundle ID matches
- Ensure Apple Sign In capability enabled

**"Stripe webhook failed"**
- Verify webhook signature validation
- Check endpoint URL is correct
- Ensure idempotency handling

**"Entitlements not updating"**
- Check subscription status in database
- Verify webhook events being processed
- Run entitlement cleanup job

**"Database connection failed"**
- Verify DATABASE_URL format
- Check network connectivity
- Ensure SSL/TLS configuration

### Logs to Monitor

```bash
# Authentication events
grep "sign in" /var/log/betterbooks/auth.log

# Payment events  
grep "purchase\|subscription" /var/log/betterbooks/payments.log

# Webhook events
grep "webhook" /var/log/betterbooks/webhooks.log

# Entitlement updates
grep "entitlement" /var/log/betterbooks/entitlements.log
```

## 📊 Monitoring & Analytics

### Key Metrics to Track

**Authentication:**
- Sign-up conversion rate by provider
- Login success/failure rates
- Token refresh patterns

**Payments:**
- Subscription conversion rates (iOS vs Web)
- Churn rates by plan type
- Revenue attribution by platform

**Technical:**
- API response times
- Webhook processing success rates
- Database query performance

### Recommended Monitoring Tools

- **Application Insights** (if using Azure)
- **Datadog** or **New Relic** for APM
- **Stripe Dashboard** for payment analytics
- **App Store Connect** for iOS metrics

## 🔄 Maintenance Tasks

### Daily
- [ ] Monitor webhook processing
- [ ] Check failed payments
- [ ] Review error logs

### Weekly  
- [ ] Run entitlement cleanup
- [ ] Backup subscription data
- [ ] Review security logs

### Monthly
- [ ] Update dependencies
- [ ] Review Apple/Stripe configurations
- [ ] Analyze conversion metrics
- [ ] Test disaster recovery

## 🎉 Go-Live Checklist

Before launching to production:

### Pre-Launch
- [ ] All tests passing
- [ ] Security audit completed
- [ ] Performance testing done
- [ ] Monitoring configured
- [ ] Backup procedures tested

### Launch Day
- [ ] DNS updated for API endpoints
- [ ] Webhooks configured for production
- [ ] iOS app submitted to App Store
- [ ] Customer support team briefed
- [ ] Rollback plan ready

### Post-Launch
- [ ] Monitor all metrics closely
- [ ] Watch for webhook failures
- [ ] Check user registration flows
- [ ] Verify payment processing
- [ ] Review support tickets

## 📞 Support Resources

- **Apple Developer Support**: For App Store review issues
- **Stripe Support**: For payment processing problems  
- **Supabase Community**: For authentication questions
- **BetterBooks DevOps**: For infrastructure issues

---

**🚀 Ready for Production!**

Once all steps are completed, your BetterBooks platform will have:
- ✅ Apple App Store compliant payments
- ✅ Secure multi-provider authentication  
- ✅ Scalable entitlements system
- ✅ GDPR-compliant user management
- ✅ Production-ready monitoring