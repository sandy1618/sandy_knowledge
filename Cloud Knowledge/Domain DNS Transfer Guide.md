# Domain DNS Transfer Guide

## Overview

This guide covers transferring domain DNS management from GoDaddy to alternative providers like Cloudflare and AWS Route 53. Understanding the difference between **DNS management** and **domain registration** is crucial.

## Key Concepts

### Domain Registration vs DNS Management

- **Domain Registration**: Where you purchase and own the domain name (e.g., GoDaddy)
- **DNS Management**: Where you control DNS records (nameservers, A records, CNAME, etc.)
- **You can separate these**: Keep registration at GoDaddy but manage DNS elsewhere

### Two Types of Transfers

1. **DNS Management Transfer** (Changing Nameservers) - Quick & Free
2. **Domain Registrar Transfer** (Moving domain ownership) - Slower & Costs money

---

## Option 1: Cloudflare DNS Management

### What is Cloudflare?

Cloudflare offers free DNS management with additional benefits:
- Free tier available
- Fast DNS propagation
- Built-in CDN and security features
- DDoS protection
- SSL/TLS certificates (free)

### Cost

- **DNS Management**: FREE
- **Domain Registration Transfer**: ~$8-15/year (includes 1-year renewal)

### Steps to Transfer DNS to Cloudflare

#### Step 1: Create Cloudflare Account

1. Go to [cloudflare.com](https://www.cloudflare.com)
2. Sign up for a free account
3. Verify your email

#### Step 2: Add Your Domain

1. Click "Add a Site" in Cloudflare dashboard
2. Enter your domain name
3. Select the **Free plan**
4. Click "Add Site"

#### Step 3: DNS Records Import

1. Cloudflare will automatically scan your existing DNS records from GoDaddy
2. Review the imported records
3. Verify all important records are present (A, CNAME, MX, TXT, etc.)
4. Click "Continue"

#### Step 4: Update Nameservers at GoDaddy

1. Cloudflare will provide you with 2 nameservers (e.g., `alice.ns.cloudflare.com` and `bob.ns.cloudflare.com`)
2. Log into your **GoDaddy account**
3. Go to "My Products" → "Domains"
4. Find your domain and click the three dots → "Manage DNS"
5. Scroll down to "Nameservers" section
6. Click "Change" → "Enter my own nameservers (advanced)"
7. Replace GoDaddy nameservers with Cloudflare nameservers
8. Save changes

#### Step 5: Wait for Propagation

- DNS changes can take 24-48 hours to propagate
- Cloudflare will email you when the transfer is complete
- You can check status in Cloudflare dashboard

### Optional: Transfer Domain Registration to Cloudflare

If you want to move the domain registration itself:

1. **Unlock domain** at GoDaddy
2. **Get authorization code** (EPP code) from GoDaddy
3. **Disable WHOIS privacy** temporarily
4. In Cloudflare, go to Domain Registration → Transfer Domain
5. Enter your domain and authorization code
6. Pay the transfer fee (~$8-15, includes 1-year renewal)
7. Approve transfer in email from GoDaddy
8. Wait 5-7 days for completion

---

## Option 2: AWS Route 53

### What is AWS Route 53?

Amazon Route 53 is AWS's scalable DNS and domain registration service:
- Highly reliable (99.99% SLA)
- Integration with AWS services
- Advanced routing policies
- Health checks and failover

### Cost

- **DNS Management**: 
  - $0.50 per hosted zone per month
  - $0.40 per million queries (first 1 billion)
- **Domain Registration Transfer**: Varies by TLD (~$12-15 for .com)

### Steps to Transfer DNS to Route 53

#### Step 1: Create AWS Account

1. Go to [aws.amazon.com](https://aws.amazon.com)
2. Create an AWS account
3. Set up billing (credit card required)

#### Step 2: Create Hosted Zone

1. Open AWS Console
2. Navigate to **Route 53** service
3. Click "Create hosted zone"
4. Enter your domain name
5. Select **Public hosted zone**
6. Click "Create hosted zone"

**Cost**: $0.50/month per hosted zone starts here

#### Step 3: Note the Nameservers

Route 53 will provide 4 nameservers (e.g., `ns-1234.awsdns-12.org`). Save these.

#### Step 4: Migrate DNS Records

You need to manually recreate your DNS records from GoDaddy:

1. Log into GoDaddy and view your current DNS records
2. In Route 53 hosted zone, click "Create record"
3. For each GoDaddy record, create equivalent in Route 53:

**Common Record Types:**

```
A Record (IPv4 address):
- Name: @ or subdomain
- Type: A
- Value: IP address (e.g., 192.0.2.1)

CNAME Record (alias):
- Name: www or subdomain
- Type: CNAME
- Value: target domain

MX Record (email):
- Name: @
- Type: MX
- Priority: 10
- Value: mail server

TXT Record (verification):
- Name: @ or subdomain
- Type: TXT
- Value: text string
```

#### Step 5: Update Nameservers at GoDaddy

1. Log into **GoDaddy account**
2. Go to "My Products" → "Domains"
3. Click your domain → "Manage DNS"
4. Scroll to "Nameservers"
5. Click "Change" → "Enter my own nameservers (advanced)"
6. Enter all 4 Route 53 nameservers
7. Save changes

#### Step 6: Verify DNS Propagation

Use command line to test:

```bash
# Check nameservers
dig NS yourdomain.com

# Check A record
dig A yourdomain.com

# Or use online tools
# https://www.whatsmydns.net/
```

### Optional: Transfer Domain Registration to Route 53

1. **Unlock domain** at GoDaddy
2. **Get authorization code** from GoDaddy
3. **Disable WHOIS privacy** temporarily
4. In Route 53, go to "Registered domains" → "Transfer domain"
5. Enter domain name and click "Check"
6. Enter authorization code
7. Complete transfer request
8. Pay transfer fee (varies by TLD)
9. Approve transfer email from GoDaddy
10. Wait 5-7 days for completion

---

## Comparison: Cloudflare vs AWS Route 53

| Feature | Cloudflare | AWS Route 53 |
|---------|-----------|--------------|
| **DNS Management Cost** | FREE | $0.50/month |
| **Query Cost** | FREE (unlimited) | $0.40/million queries |
| **Free Tier** | Yes (generous) | No (pay per use) |
| **SSL Certificate** | Free | Via AWS Certificate Manager |
| **CDN** | Included free | Separate service (CloudFront) |
| **DDoS Protection** | Included free | Separate service (Shield) |
| **AWS Integration** | No | Excellent |
| **Speed** | Very fast | Very fast |
| **Ease of Use** | Beginner-friendly | AWS knowledge needed |
| **Best For** | Most users, free tier | AWS-heavy workloads |

---

## Recommendation

### Choose Cloudflare if:
- You want FREE DNS management
- You need simple, quick setup
- You want built-in CDN and security
- You're not heavily using AWS services
- **Best for beginners and cost-conscious users**

### Choose AWS Route 53 if:
- You're already using AWS services (EC2, S3, CloudFront, etc.)
- You need advanced routing (geolocation, latency-based)
- You need health checks and failover
- You're okay with monthly costs
- **Best for AWS-integrated infrastructure**

---

## AWS Route 53 Benefits for AWS Users

If you're already using AWS services, Route 53 provides significant advantages:

### 1. **Seamless AWS Service Integration**

#### EC2 Integration
- **Automatic DNS updates** for EC2 instances
- **Private hosted zones** for VPC-internal DNS resolution
- **Alias records** to EC2 instances (no additional charge for queries)
- **Health checks** on EC2 instances with automatic failover

#### Elastic Load Balancer (ELB/ALB/NLB)
- **Alias records to load balancers** (free queries, unlike CNAME)
- **Automatic DNS updates** when load balancer IPs change
- **Zone apex support** (yourdomain.com → ELB, not possible with CNAME)
- **Integrated health checks**

#### S3 Website Hosting
- **Direct alias to S3 website endpoints**
- **Free queries** to S3 alias records
- Example: `yourdomain.com` → S3 bucket `yourdomain.com`

#### CloudFront CDN
- **Alias records to CloudFront distributions** (no query charges)
- **Automatic SSL certificate** via AWS Certificate Manager
- **Global edge location** integration
- **Fast propagation** to CDN edge locations

#### API Gateway
- **Custom domain names** for APIs
- **Alias records to API Gateway** endpoints
- **Regional and edge-optimized** routing

#### Elastic Beanstalk
- **Automatic DNS for environments**
- **Blue-green deployments** with DNS switching
- **Environment-specific URLs**

### 2. **Advanced Routing Policies**

#### Geolocation Routing
```
Europe users → EU region servers
US users → US region servers
Asia users → Asia region servers
```
**Use case**: Comply with GDPR, reduce latency, localized content

#### Latency-Based Routing
```
Automatically routes users to the AWS region with lowest latency
```
**Use case**: Global applications with multi-region deployment

#### Weighted Routing
```
80% traffic → Production (stable version)
20% traffic → Canary (new version)
```
**Use case**: A/B testing, gradual rollouts, blue-green deployments

#### Failover Routing
```
Primary server healthy → Route to primary
Primary server down → Automatic failover to secondary
```
**Use case**: High availability, disaster recovery

#### Geoproximity Routing
```
Route based on geographic location + bias adjustments
```
**Use case**: Control traffic distribution across regions

### 3. **Health Checks and Monitoring**

- **Endpoint health checks** (HTTP/HTTPS/TCP)
- **CloudWatch integration** for monitoring
- **SNS notifications** on health check failures
- **Automatic failover** when endpoints become unhealthy
- **Calculated health checks** (combine multiple checks)

### 4. **AWS Certificate Manager (ACM) Integration**

- **Free SSL/TLS certificates** for AWS services
- **Automatic renewal** (no manual intervention)
- **Wildcard certificates** (*.yourdomain.com)
- **Integration with**: CloudFront, ELB, API Gateway

### 5. **Cost Optimization**

#### Alias Records (AWS-Specific Feature)
- **No query charges** for alias records pointing to:
  - CloudFront distributions
  - Elastic Load Balancers
  - S3 website endpoints
  - API Gateway
  - Other Route 53 records in same hosted zone

**Example savings:**
```
Standard A record to CloudFront: $0.40 per million queries
Alias record to CloudFront: $0.00 (FREE)

For 10 million queries/month:
CNAME approach: $4.00
Alias approach: $0.00
Annual savings: $48
```

### 6. **Security Features**

- **DNSSEC** (Domain Name System Security Extensions)
- **IAM integration** (fine-grained access control)
- **Route 53 Resolver** for DNS firewall
- **VPC DNS resolution** (private DNS)
- **Query logging** to CloudWatch or S3
- **AWS Shield integration** (DDoS protection)

### 7. **Infrastructure as Code (IaC)**

- **CloudFormation** templates
- **Terraform** provider
- **AWS CDK** support
- **Version control** for DNS records
- **Automated deployments** with CI/CD

### 8. **Developer-Friendly Features**

- **AWS CLI** for automation
- **SDK support** (Python, Node.js, Java, etc.)
- **API-driven** configuration
- **Programmatic DNS updates**

### 9. **Private Hosted Zones**

- **Internal DNS** for VPC resources
- **Split-view DNS** (different records for internal vs external)
- **No internet exposure** for private resources
- **Cross-account VPC association**

**Example:**
```
External DNS: api.yourdomain.com → Public IP
Internal DNS: api.yourdomain.com → Private IP (10.0.1.5)
```

### 10. **Business Continuity**

- **99.99% availability SLA**
- **Global anycast network**
- **Multi-region redundancy**
- **Automatic scaling**
- **No infrastructure management**

---

## Real-World AWS Integration Examples

### Example 1: Web Application on AWS

**Setup:**
```
Domain: example.com
DNS: Route 53
CDN: CloudFront
Storage: S3
Compute: ECS/Fargate
Load Balancer: ALB
Certificate: ACM (free)
```

**Route 53 Records:**
- `example.com` → Alias to CloudFront (free queries)
- `www.example.com` → Alias to CloudFront (free queries)
- `api.example.com` → Alias to ALB (free queries)
- `*.api.example.com` → Alias to API Gateway

**Benefits:**
- Zero query charges for alias records
- Free SSL certificates
- Automatic failover with health checks
- Global CDN with DNS integration

### Example 2: Multi-Region High Availability

**Setup:**
```
Primary region: us-east-1
Secondary region: eu-west-1
Routing: Latency-based + Health checks
```

**Configuration:**
- Health checks on both regions
- Automatic failover if primary fails
- Users routed to nearest healthy region
- CloudWatch alarms for failures

**Cost:**
- Hosted zone: $0.50/month
- Health checks: $0.50 each (2 = $1.00/month)
- Queries: Free (alias records)
- **Total: ~$1.50/month for global HA DNS**

### Example 3: Microservices Architecture

**Setup:**
```
auth.example.com → Lambda + API Gateway
api.example.com → ECS + ALB
cdn.example.com → CloudFront + S3
admin.example.com → EC2 + ELB
```

**Route 53 Benefits:**
- Each service gets its own subdomain
- Alias records to AWS services (free queries)
- Independent health checks per service
- Easy service discovery within VPC

---

## Cost Comparison: Cloudflare vs Route 53 for AWS Users

| Scenario | Cloudflare | Route 53 |
|----------|-----------|----------|
| **Simple website (no AWS)** | $0 | $6/year |
| **Website + AWS services** | $0 | $6/year* |
| **High traffic (10M queries)** | $0 | $4-10/month** |
| **Multi-region failover** | $0 | $7.50/month** |
| **Advanced routing** | Limited | Full featured |
| **AWS integration** | None | Native |
| **Management overhead*** | Higher | Lower |

*With alias records to AWS services
**Includes hosted zone + health checks, but alias queries are free
***For AWS-heavy infrastructure

### When Route 53's Cost is Worth It:

1. ✅ Using 3+ AWS services that need DNS
2. ✅ Need automatic failover/health checks
3. ✅ Multi-region deployment
4. ✅ Heavy API Gateway usage
5. ✅ Infrastructure as Code (CloudFormation/Terraform)
6. ✅ Private DNS for VPC resources
7. ✅ Advanced routing (latency, geolocation)

### When Cloudflare Makes More Sense:

1. ✅ Simple website/blog
2. ✅ Budget-conscious (want $0 cost)
3. ✅ Minimal AWS integration
4. ✅ Need free CDN + DDoS protection
5. ✅ Don't need advanced routing
6. ✅ Prefer web UI over CLI/API

---

## Important Notes

### Can I Switch DNS Providers Later?

**YES!** You can switch DNS management providers anytime because:

- **You still own the domain** at GoDaddy (or wherever it's registered)
- **DNS provider is just a service** you point to via nameservers
- **Switching is the same process** - just change nameservers again

**Example Scenario**: Currently using Cloudflare → Lost credentials → Want to switch to Route 53

**Solution:**
1. You can change nameservers at GoDaddy anytime (you own the domain!)
2. Set up new DNS provider (Route 53, another Cloudflare account, or any other)
3. Recreate your DNS records at the new provider
4. Update nameservers in GoDaddy to point to new provider
5. Old provider (Cloudflare) becomes irrelevant after propagation

**Key Point**: Your domain registrar (GoDaddy) always has the "master control" over nameservers. You can change DNS management providers as many times as you want.

### Critical: Which Credentials Do You Need?

**To switch DNS providers, you ONLY need:**
- ✅ **GoDaddy credentials** (your domain registrar)
- ❌ **NOT Cloudflare credentials** (old DNS provider)
- ✅ **New DNS provider credentials** (Route 53/AWS account)

**Why?**
- **GoDaddy = Domain Owner** → Controls nameservers
- **Cloudflare/Route 53 = DNS Service** → Just follows nameserver settings

**In simple terms:** 
- If you lose Cloudflare password → You can still switch to Route 53 (via GoDaddy)
- If you lose GoDaddy password → You're locked out (need to recover GoDaddy access)
- **Always protect your GoDaddy (registrar) credentials!**

### Before Any Transfer

1. ✅ **Backup your DNS records** (screenshot or export from current provider)
2. ✅ **Check domain lock status** at GoDaddy
3. ✅ **Verify email access** (you'll receive transfer confirmation emails)
4. ✅ **Check domain expiration** (should have 60+ days remaining)
5. ✅ **Note down current TTL values** for records

### During Transfer

- **Minimize downtime**: Keep existing DNS records active during nameserver change
- **Don't delete old DNS records** until new nameservers are fully propagated
- **Test thoroughly** before removing GoDaddy DNS

### After Transfer

- ✅ Verify all services work (website, email, subdomains)
- ✅ Monitor for 48-72 hours
- ✅ Update nameservers in other services if needed

---

## Cost Summary

### Just DNS Management (Nameserver Change)

| Provider | Setup Cost | Monthly Cost | Annual Cost |
|----------|-----------|--------------|-------------|
| **Cloudflare** | $0 | $0 | $0 |
| **Route 53** | $0 | $0.50 | $6.00 |

**Verdict**: Cloudflare DNS management is completely free! Route 53 costs $6/year.

### Full Domain Transfer (Registration + DNS)

| Provider | Transfer Fee | Yearly Renewal | Total Year 1 |
|----------|-------------|----------------|--------------|
| **Cloudflare** | ~$10 | ~$10 | ~$10 |
| **Route 53** | ~$12-15 | ~$12-15 | ~$18-21* |

*Includes $6 for DNS hosting

---

## Quick Start Guide

### Fastest Free Option (Cloudflare DNS Only):

1. Sign up at Cloudflare (5 mins)
2. Add your domain (2 mins)
3. Change nameservers at GoDaddy (3 mins)
4. Wait 24-48 hours for propagation
5. **Total cost: $0**

### AWS Route 53 (DNS Only):

1. Create AWS account
2. Create Route 53 hosted zone ($0.50/month)
3. Copy DNS records from GoDaddy
4. Change nameservers at GoDaddy
5. **Total cost: $6/year**

---

## Common Scenarios

### Scenario 1: Lost Access to Current DNS Provider

**Problem**: You're using Cloudflare for DNS management, but lost your credentials.

**Solution**:
1. **You still have control!** Log into GoDaddy (your domain registrar)
2. Set up a new DNS provider (new Cloudflare account, Route 53, etc.)
3. Manually recreate your DNS records at the new provider
4. Change nameservers at GoDaddy to point to the new provider
5. Wait 24-48 hours for propagation
6. Your old Cloudflare account becomes irrelevant

**Important**: The domain registrar (GoDaddy) always has ultimate control over nameservers, regardless of your DNS provider credentials.

### Scenario 2: Switching Between DNS Providers

**From Cloudflare to Route 53**:
1. Set up Route 53 hosted zone
2. Export/copy DNS records from Cloudflare (while you still have access)
3. Import records into Route 53
4. Change nameservers at GoDaddy to Route 53's nameservers
5. Keep Cloudflare active for 48 hours during propagation
6. Delete Cloudflare zone after confirming everything works

**From Route 53 to Cloudflare**:
- Same process, just reversed

### Scenario 3: Emergency Recovery Without DNS Access

**If you lost DNS provider access AND don't have a backup**:

1. **Identify your current DNS records** using command line:
   ```bash
   # Check all DNS records
   dig ANY yourdomain.com
   
   # Check specific record types
   dig A yourdomain.com
   dig MX yourdomain.com
   dig TXT yourdomain.com
   dig CNAME www.yourdomain.com
   ```

2. **Use online DNS lookup tools**:
   - https://mxtoolbox.com/SuperTool.aspx
   - https://dnschecker.org/
   - https://www.nslookup.io/

3. **Recreate records** at new DNS provider based on what you found

4. **Update nameservers** at GoDaddy

**Pro Tip**: Always keep a backup of your DNS records in a safe place!

### Scenario 4: Managing Multiple Domains in One DNS Account

**Question**: Can I manage multiple domains (from different GoDaddy accounts) in one Cloudflare/Route 53 account?

**Answer: YES! Absolutely!**

#### How It Works:

**Cloudflare:**
- ✅ One Cloudflare account can manage **unlimited domains** (Free plan)
- ✅ Each domain gets **unique nameservers** (different per domain)
- ✅ Domains can come from **different registrars** (GoDaddy, Namecheap, etc.)
- ✅ Each domain has **separate DNS records** and settings

**Example Setup:**
```
Cloudflare Account: john@example.com

Domain 1: mybusiness.com (from GoDaddy account A)
├── Nameservers: alice.ns.cloudflare.com, bob.ns.cloudflare.com
└── DNS Records: Separate

Domain 2: myportfolio.com (from GoDaddy account B)
├── Nameservers: charlie.ns.cloudflare.com, diana.ns.cloudflare.com
└── DNS Records: Separate

Domain 3: myside-project.org (from Namecheap)
├── Nameservers: eve.ns.cloudflare.com, frank.ns.cloudflare.com
└── DNS Records: Separate
```

**Important Notes:**
- Each domain gets **different Cloudflare nameservers**
- You manage all domains from **one Cloudflare dashboard**
- **No additional cost** (all free on Free plan)
- Domains remain registered at their **original registrars**

**AWS Route 53:**
- ✅ One AWS account can manage **multiple hosted zones**
- ✅ Each domain = separate hosted zone = **$0.50/month each**
- ✅ All domains share the **same 4 Route 53 nameservers** (per hosted zone)
- ✅ Domains can come from **any registrar**

**Example Setup:**
```
AWS Account: john@example.com

Hosted Zone 1: mybusiness.com ($0.50/month)
├── Nameservers: ns-1234.awsdns-12.org (unique to this zone)
└── DNS Records: Separate

Hosted Zone 2: myportfolio.com ($0.50/month)
├── Nameservers: ns-5678.awsdns-34.org (unique to this zone)
└── DNS Records: Separate

Total cost: $1.00/month for 2 domains
```

#### Step-by-Step: Adding Second Domain to Cloudflare

**You already have domain1.com in Cloudflare:**

1. **Log into same Cloudflare account**
2. Click **"Add a Site"** in dashboard
3. Enter **domain2.com** (from your other GoDaddy account)
4. Choose **Free plan**
5. Cloudflare scans and imports DNS records
6. **Note the NEW nameservers** (different from domain1!)
   - Example: `george.ns.cloudflare.com`, `helen.ns.cloudflare.com`
7. **Log into your other GoDaddy account**
8. Find **domain2.com** → Manage DNS → Change nameservers
9. Enter the **new Cloudflare nameservers** (the ones for domain2)
10. Save and wait for propagation

**Result**: Both domains managed in one Cloudflare account, each with their own nameservers!

#### Step-by-Step: Adding Second Domain to Route 53

**You already have domain1.com in Route 53:**

1. **Log into same AWS account**
2. Go to **Route 53** → Hosted zones
3. Click **"Create hosted zone"**
4. Enter **domain2.com** name
5. Select **Public hosted zone**
6. Click **"Create hosted zone"**
7. **Note the 4 nameservers** (unique to this hosted zone)
8. Manually create DNS records for domain2.com
9. **Log into your other GoDaddy account**
10. Find **domain2.com** → Manage DNS → Change nameservers
11. Enter all **4 Route 53 nameservers**
12. Save and wait for propagation

**Cost**: $0.50/month per hosted zone (so 2 domains = $1.00/month)

#### Key Differences

| Feature | Cloudflare | Route 53 |
|---------|-----------|----------|
| **Multiple domains cost** | FREE (unlimited) | $0.50/month per domain |
| **Nameservers per domain** | Unique pair per domain | Unique set (4) per zone |
| **Management** | Single dashboard | Single AWS console |
| **DNS record isolation** | Automatic | Automatic (per zone) |
| **Best for multiple domains** | Free option | AWS integration |

#### Common Questions

**Q: Do I need separate Cloudflare accounts for each domain?**
A: No! One account can manage unlimited domains.

**Q: Will the nameservers be the same for all my domains?**
A: No, each domain gets unique nameservers (both Cloudflare and Route 53).

**Q: Can I mix registrars (GoDaddy + Namecheap + Google Domains)?**
A: Yes! DNS management is independent of where you registered.

**Q: Do my domains interfere with each other?**
A: No, DNS records are completely separate per domain.

**Q: Can I have different DNS settings per domain?**
A: Yes, each domain has its own configuration (SSL, caching, security, etc.).

---

## Troubleshooting

### DNS Not Propagating

```bash
# Check current nameservers
dig NS yourdomain.com +short

# Check from specific DNS server
dig @8.8.8.8 yourdomain.com

# Flush local DNS cache (macOS)
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```

### Website Down After Transfer

1. Check if nameservers are updated: `dig NS yourdomain.com`
2. Verify A record points to correct IP
3. Check TTL values (lower = faster propagation)
4. Wait full 48 hours before troubleshooting

### Email Not Working

1. Verify MX records are correctly configured
2. Check TXT records (SPF, DKIM, DMARC)
3. Ensure priority values match original setup

---

## Additional Resources

- [Cloudflare DNS Setup Guide](https://developers.cloudflare.com/dns/)
- [AWS Route 53 Documentation](https://docs.aws.amazon.com/route53/)
- [DNS Propagation Checker](https://www.whatsmydns.net/)
- [Domain Transfer Checklist](https://www.icann.org/resources/pages/domain-transfer-2016-06-28-en)

---

## Summary

**For most users**: Start with Cloudflare DNS management (free) by just changing nameservers. You keep your domain at GoDaddy but get free DNS, CDN, and security features.

**For AWS users**: Route 53 makes sense if you're already invested in AWS infrastructure, despite the $6/year cost.

**Transfer domain registration** only if you want to consolidate everything in one place - but this is optional and can be done later!

---

*Last updated: November 24, 2025*
