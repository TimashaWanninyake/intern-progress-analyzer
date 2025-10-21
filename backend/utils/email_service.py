import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from config import EMAIL_ENABLED, EMAIL_HOST, EMAIL_PORT, EMAIL_USER, EMAIL_PASSWORD, EMAIL_FROM, EMAIL_FROM_NAME

def send_email(to_email, subject, body_html, body_text=None):
    """
    Send email using SMTP
    
    Args:
        to_email: Recipient email address
        subject: Email subject
        body_html: HTML body content
        body_text: Plain text body content (optional)
    
    Returns:
        bool: True if email sent successfully, False otherwise
    """
    
    # If email is not enabled, just print to console (development mode)
    if not EMAIL_ENABLED:
        print(f"\n{'='*60}")
        print(f"EMAIL NOT SENT (EMAIL_ENABLED=False)")
        print(f"To: {to_email}")
        print(f"Subject: {subject}")
        print(f"Body: {body_text or body_html}")
        print(f"{'='*60}\n")
        return True
    
    # Validate email configuration
    if not EMAIL_USER or not EMAIL_PASSWORD:
        print("ERROR: EMAIL_USER or EMAIL_PASSWORD not configured")
        return False
    
    try:
        # Create message
        msg = MIMEMultipart('alternative')
        msg['From'] = f"{EMAIL_FROM_NAME} <{EMAIL_FROM}>"
        msg['To'] = to_email
        msg['Subject'] = subject
        
        # Add plain text version
        if body_text:
            part1 = MIMEText(body_text, 'plain')
            msg.attach(part1)
        
        # Add HTML version
        part2 = MIMEText(body_html, 'html')
        msg.attach(part2)
        
        # Connect to SMTP server
        print(f"Connecting to {EMAIL_HOST}:{EMAIL_PORT}...")
        server = smtplib.SMTP(EMAIL_HOST, EMAIL_PORT)
        server.ehlo()
        server.starttls()
        server.ehlo()
        
        # Login
        print(f"Logging in as {EMAIL_USER}...")
        server.login(EMAIL_USER, EMAIL_PASSWORD)
        
        # Send email
        print(f"Sending email to {to_email}...")
        server.sendmail(EMAIL_FROM, to_email, msg.as_string())
        server.quit()
        
        print(f"✓ Email sent successfully to {to_email}")
        return True
        
    except smtplib.SMTPAuthenticationError:
        print("ERROR: SMTP Authentication failed. Check EMAIL_USER and EMAIL_PASSWORD")
        print("For Gmail, you need to use an App Password, not your regular password")
        print("Visit: https://myaccount.google.com/apppasswords")
        return False
        
    except smtplib.SMTPException as e:
        print(f"ERROR: SMTP error occurred: {str(e)}")
        return False
        
    except Exception as e:
        print(f"ERROR: Failed to send email: {str(e)}")
        return False


def send_otp_email(to_email, otp):
    """
    Send OTP email for password reset
    
    Args:
        to_email: Recipient email address
        otp: 6-digit OTP code
    
    Returns:
        bool: True if email sent successfully
    """
    subject = "Password Reset OTP - Intern Analytics"
    
    # Plain text version
    body_text = f"""
    Password Reset Request
    
    Your OTP code is: {otp}
    
    This code will expire in 10 minutes.
    
    If you did not request this password reset, please ignore this email.
    
    ---
    Intern Analytics System
    """
    
    # HTML version
    body_html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body {{
                font-family: Arial, sans-serif;
                line-height: 1.6;
                color: #333;
            }}
            .container {{
                max-width: 600px;
                margin: 0 auto;
                padding: 20px;
                background-color: #f9f9f9;
            }}
            .header {{
                background-color: #FF9800;
                color: white;
                padding: 20px;
                text-align: center;
                border-radius: 5px 5px 0 0;
            }}
            .content {{
                background-color: white;
                padding: 30px;
                border-radius: 0 0 5px 5px;
            }}
            .otp-box {{
                background-color: #f0f0f0;
                border: 2px solid #FF9800;
                padding: 20px;
                text-align: center;
                font-size: 32px;
                font-weight: bold;
                letter-spacing: 8px;
                margin: 20px 0;
                border-radius: 5px;
            }}
            .warning {{
                background-color: #fff3cd;
                border: 1px solid #ffc107;
                padding: 15px;
                border-radius: 5px;
                margin-top: 20px;
            }}
            .footer {{
                text-align: center;
                padding: 20px;
                color: #666;
                font-size: 12px;
            }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>Password Reset Request</h1>
            </div>
            <div class="content">
                <p>Hello,</p>
                <p>You have requested to reset your password for the Intern Analytics System.</p>
                <p>Your One-Time Password (OTP) is:</p>
                
                <div class="otp-box">
                    {otp}
                </div>
                
                <p><strong>Important:</strong> This code will expire in <strong>10 minutes</strong>.</p>
                
                <div class="warning">
                    <strong>⚠️ Security Notice:</strong><br>
                    If you did not request this password reset, please ignore this email and ensure your account is secure.
                </div>
            </div>
            <div class="footer">
                <p>This is an automated message from Intern Analytics System</p>
                <p>Please do not reply to this email</p>
            </div>
        </div>
    </body>
    </html>
    """
    
    return send_email(to_email, subject, body_html, body_text)
