# Email Setup Guide for OTP Functionality

## 🚀 Quick Start (Development Mode)

By default, emails are **NOT sent** - OTPs are printed to the console for testing.

To test the forgot password feature:
1. Run the backend: `python app.py`
2. Go to forgot password page
3. Enter email and click "Send OTP"
4. Check the terminal/console where Flask is running
5. You'll see the OTP printed like this:
   ```
   ============================================================
   EMAIL NOT SENT (EMAIL_ENABLED=False)
   To: admin@company.com
   Subject: Password Reset OTP - Intern Analytics
   Body: Your OTP code is: 123456
   ============================================================
   ```
6. Copy the OTP and use it in the app

---

## 📧 Enable Real Email Sending (Production)

To actually send emails to user inboxes, follow these steps:

### Step 1: Choose Email Service

**Option A: Gmail (Recommended for Testing)**
- Free and easy to set up
- Requires App Password (not your regular Gmail password)
- Daily limit: 500 emails/day

**Option B: SendGrid**
- Professional email service
- Free tier: 100 emails/day
- Better deliverability

**Option C: AWS SES**
- Amazon's email service
- Pay as you go
- Very reliable

---

### Step 2: Gmail Setup (Easiest)

#### 2.1 Enable 2-Factor Authentication
1. Go to https://myaccount.google.com/security
2. Click "2-Step Verification"
3. Follow the steps to enable it

#### 2.2 Create App Password
1. Go to https://myaccount.google.com/apppasswords
2. Sign in if needed
3. In "Select app", choose **Mail**
4. In "Select device", choose **Other** and enter "Intern Analytics"
5. Click **Generate**
6. Copy the 16-character password (e.g., `abcd efgh ijkl mnop`)
7. **Save this password** - you won't see it again!

#### 2.3 Configure Backend
1. Create a `.env` file in the `backend/` folder:
   ```bash
   cd backend
   copy .env.example .env
   ```

2. Edit the `.env` file:
   ```env
   EMAIL_ENABLED=true
   EMAIL_HOST=smtp.gmail.com
   EMAIL_PORT=587
   EMAIL_USER=your-email@gmail.com
   EMAIL_PASSWORD=abcd efgh ijkl mnop
   EMAIL_FROM=your-email@gmail.com
   EMAIL_FROM_NAME=Intern Analytics System
   ```

3. Install `python-dotenv` (if not already installed):
   ```bash
   pip install python-dotenv
   ```

4. Update `config.py` to load from `.env` file (already done)

5. Restart the Flask server

---

### Step 3: Test Email Sending

1. Start the backend:
   ```bash
   cd backend
   python app.py
   ```

2. Check console for connection messages:
   ```
   Connecting to smtp.gmail.com:587...
   Logging in as your-email@gmail.com...
   Sending email to admin@company.com...
   ✓ Email sent successfully to admin@company.com
   ```

3. Go to the forgot password page in your app

4. Enter a valid admin/supervisor email

5. Click "Send OTP"

6. Check the email inbox - you should receive an email with:
   - Subject: "Password Reset OTP - Intern Analytics"
   - Styled HTML email with the 6-digit OTP
   - Expiry notice (10 minutes)

---

## 🛠️ Troubleshooting

### Error: "SMTP Authentication failed"
**Cause:** Wrong email or password  
**Solution:**
- Make sure you're using an **App Password**, not your regular Gmail password
- Double-check the email address
- Regenerate App Password if needed

### Error: "SMTP connection timeout"
**Cause:** Network or firewall blocking SMTP port  
**Solution:**
- Check if port 587 is open
- Try using port 465 with SSL:
  ```env
  EMAIL_PORT=465
  ```
- Check your antivirus/firewall settings

### Error: "Less secure app access"
**Cause:** Old Gmail security setting  
**Solution:**
- This is deprecated - use App Passwords instead (Step 2.2)

### Emails not arriving
**Cause:** Might be in spam folder or blocked  
**Solution:**
- Check spam/junk folder
- Add sender email to contacts
- Use a verified domain for `EMAIL_FROM`

### "EMAIL_USER or EMAIL_PASSWORD not configured"
**Cause:** `.env` file not loaded  
**Solution:**
- Make sure `.env` file exists in `backend/` folder
- Install `python-dotenv`: `pip install python-dotenv`
- Restart Flask server

---

## 🔐 Security Best Practices

### For Development:
✅ Keep `EMAIL_ENABLED=false` and use console output  
✅ Remove `debug_otp` from API response before production  
✅ Never commit `.env` file to git (add to `.gitignore`)

### For Production:
✅ Use environment variables instead of `.env` file  
✅ Enable `EMAIL_ENABLED=true`  
✅ Remove `debug_otp` field from `/send-otp` response  
✅ Use professional email service (SendGrid, AWS SES)  
✅ Add rate limiting to prevent spam  
✅ Monitor email sending logs  
✅ Use HTTPS for all connections  

---

## 📊 Email Service Comparison

| Service | Free Tier | Setup Difficulty | Reliability | Best For |
|---------|-----------|------------------|-------------|----------|
| Gmail | 500/day | Easy | Good | Testing/Development |
| SendGrid | 100/day | Medium | Excellent | Small Production |
| AWS SES | Pay-per-use | Hard | Excellent | Large Production |
| Mailgun | 100/day | Medium | Excellent | Medium Production |

---

## 🔧 Advanced Configuration

### Using SendGrid

1. Sign up at https://sendgrid.com/
2. Create API Key
3. Update `.env`:
   ```env
   EMAIL_ENABLED=true
   EMAIL_HOST=smtp.sendgrid.net
   EMAIL_PORT=587
   EMAIL_USER=apikey
   EMAIL_PASSWORD=<your-sendgrid-api-key>
   ```

### Using AWS SES

1. Sign up for AWS
2. Verify domain and email
3. Create SMTP credentials
4. Update `.env`:
   ```env
   EMAIL_ENABLED=true
   EMAIL_HOST=email-smtp.us-east-1.amazonaws.com
   EMAIL_PORT=587
   EMAIL_USER=<your-smtp-username>
   EMAIL_PASSWORD=<your-smtp-password>
   ```

---

## 📝 Email Template Customization

Edit `backend/utils/email_service.py` to customize:
- Email subject
- HTML styling
- Company logo
- Footer text
- Colors and fonts

---

## ✅ Testing Checklist

- [ ] OTP appears in console (development mode)
- [ ] Email configuration loaded from `.env`
- [ ] SMTP connection successful
- [ ] Email arrives in inbox (not spam)
- [ ] HTML email displays correctly
- [ ] OTP is readable and correct
- [ ] Expiry time is shown (10 minutes)
- [ ] Multiple emails can be sent
- [ ] Error messages are clear

---

## 🚀 Production Deployment

Before going live:

1. **Update `.env`:**
   ```env
   EMAIL_ENABLED=true
   ```

2. **Remove debug OTP from API response:**
   Edit `backend/routes/forgot_password.py`:
   ```python
   return jsonify({
       'success': True, 
       'message': 'OTP sent to your email. Please check your inbox.'
       # Remove: 'debug_otp': otp
   }), 200
   ```

3. **Add to `.gitignore`:**
   ```
   .env
   *.pyc
   __pycache__/
   ```

4. **Use environment variables on server:**
   - Set `EMAIL_ENABLED=true`
   - Set `EMAIL_USER`, `EMAIL_PASSWORD`, etc.

5. **Test thoroughly before launch!**

---

## 📞 Support

If you encounter issues:
1. Check console/terminal for error messages
2. Verify `.env` configuration
3. Test SMTP connection manually
4. Check email service status
5. Review logs in Flask console

---

**Happy Emailing! 📧✨**
