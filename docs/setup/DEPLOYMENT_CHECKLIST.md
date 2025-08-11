# 📱 BetterBooks Production Deployment Checklist

## ☁️ **Phase 1: Google Cloud Setup**

### Prerequisites Setup
- [ ] Google Cloud account with billing enabled
- [ ] Install `gcloud` CLI: `curl https://sdk.cloud.google.com | bash`
- [ ] Install `kubectl`: `gcloud components install kubectl`
- [ ] Install `helm`: `curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash`
- [ ] Get Gemini API key from Google AI Studio

### Cloud Infrastructure
- [ ] Run: `chmod +x deployment/setup-gcloud.sh && ./deployment/setup-gcloud.sh`
- [ ] Update Gemini API key: `kubectl patch secret app-secrets -p='{"data":{"gemini-api-key":"BASE64_ENCODED_KEY"}}'`
- [ ] Reserve static IP: `gcloud compute addresses create betterbooks-ip --global`
- [ ] Get IP address: `gcloud compute addresses describe betterbooks-ip --global`
- [ ] Update DNS A record to point your domain to the IP

## 🐳 **Phase 2: Build & Deploy Services**

### Docker Images
- [ ] Run: `chmod +x deployment/build-and-push.sh && ./deployment/build-and-push.sh`
- [ ] Verify images in GCR: `gcloud container images list --repository=gcr.io/betterbooks-prod`

### Kubernetes Deployment
- [ ] Update Helm dependencies: `cd infra/helm/betterbooks && helm dependency update`
- [ ] Deploy to cluster: `helm install betterbooks infra/helm/betterbooks/ --values infra/helm/betterbooks/values.yaml`
- [ ] Check pod status: `kubectl get pods`
- [ ] Check services: `kubectl get services`
- [ ] Check ingress: `kubectl get ingress`

### Upload Audiobooks
- [ ] Upload audiobook files: `gsutil -m cp -r book_files/* gs://betterbooks-prod-audiobooks/`
- [ ] Update volume mounts in Helm values to use GCS

## 📱 **Phase 3: Mobile App TestFlight**

### Apple Developer Setup
- [ ] **Apple Developer Account** ($99/year): https://developer.apple.com/account/
- [ ] Create App ID: `com.betterbooks.app`
- [ ] Generate provisioning profiles for distribution
- [ ] Set up App Store Connect app entry

### App Configuration
- [ ] Update `mobile_app/lib/api_config.dart` with production URL
- [ ] Update app version in `pubspec.yaml`
- [ ] Update Bundle ID in `ios/Runner.xcodeproj`
- [ ] Add production signing certificates

### Build & Upload
- [ ] Run: `chmod +x deployment/testflight-build.sh && ./deployment/testflight-build.sh`
- [ ] Upload IPA to App Store Connect via Xcode Organizer or Transporter
- [ ] Submit for TestFlight review (24-48 hours)
- [ ] Add beta testers to TestFlight
- [ ] Send invitation links

## 🧪 **Phase 4: Testing & Verification**

### Backend Testing
- [ ] API health check: `curl https://api.betterbooks.app/health`
- [ ] Books endpoint: `curl https://api.betterbooks.app/books/list`
- [ ] Personas endpoint: `curl https://api.betterbooks.app/configs`
- [ ] Complete AI flow test with real API calls

### Mobile App Testing
- [ ] Install TestFlight app on test device
- [ ] Accept beta invitation
- [ ] Test app installation and launch
- [ ] Test audiobook playback
- [ ] Test chat functionality
- [ ] Test voice AI queries
- [ ] Test persona switching
- [ ] Test cover image loading

### Performance & Monitoring
- [ ] Set up Cloud Monitoring dashboards
- [ ] Configure alerts for service health
- [ ] Test app performance under load
- [ ] Monitor resource usage and costs

## 🚀 **Phase 5: Beta Distribution**

### TestFlight Management
- [ ] Create testing groups (Internal, External)
- [ ] Add beta testers (up to 10,000 external testers)
- [ ] Configure TestFlight metadata and screenshots
- [ ] Enable crash reporting and analytics

### User Communication
- [ ] Prepare beta testing instructions
- [ ] Create feedback collection system
- [ ] Set up user support channels
- [ ] Document known issues and workarounds

## 📊 **Phase 6: Monitoring & Maintenance**

### Ongoing Tasks
- [ ] Monitor application logs: `kubectl logs -f deployment/api-gateway`
- [ ] Track resource usage and costs
- [ ] Regular security updates
- [ ] Performance optimization
- [ ] User feedback collection and analysis

---

## 🛠️ **Quick Commands Reference**

```bash
# Check cluster status
kubectl get all

# View logs
kubectl logs -f deployment/api-gateway

# Update deployment
helm upgrade betterbooks infra/helm/betterbooks/

# Scale services
kubectl scale deployment api-gateway --replicas=3

# Get external IP
kubectl get ingress
```

## 📞 **Support & Troubleshooting**

- Google Cloud Console: https://console.cloud.google.com
- Kubernetes Dashboard: `kubectl proxy` then http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
- App Store Connect: https://appstoreconnect.apple.com

## 💰 **Estimated Costs (Monthly)**
- GKE Cluster (2 nodes): ~$50
- CloudSQL PostgreSQL: ~$10
- Load Balancer: ~$20
- Storage & Bandwidth: ~$5-20
- **Total: ~$85-100/month**