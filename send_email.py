import smtplib
import json
import sys
import os
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

def load_config(config_path):
    try:
        with open(config_path, 'r') as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"Error: Configuration file '{config_path}' not found.")
        sys.exit(1)
    except json.JSONDecodeError:
        print(f"Error: Invalid JSON in '{config_path}'.")
        sys.exit(1)

def send_email(subject, body, config):
    try:
        msg = MIMEMultipart()
        msg['From'] = config['sender_email']
        msg['To'] = config['recipient_email']
        msg['Subject'] = subject

        msg.attach(MIMEText(body, 'plain'))

        server = smtplib.SMTP(config['smtp_server'], config['smtp_port'])
        server.starttls()
        server.login(config['sender_email'], config['sender_password'])
        text = msg.as_string()
        server.sendmail(config['sender_email'], config['recipient_email'], text)
        server.quit()
        print("Email sent successfully.")
    except Exception as e:
        print(f"Failed to send email: {e}")
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 send_email.py <subject> <body> [config_file]")
        sys.exit(1)

    subject = sys.argv[1]
    body = sys.argv[2]
    config_file = sys.argv[3] if len(sys.argv) > 3 else "email_config.json"
    
    # Resolve absolute path if needed, or assume relative to script directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    config_path = os.path.join(script_dir, config_file)

    config = load_config(config_path)
    send_email(subject, body, config)
