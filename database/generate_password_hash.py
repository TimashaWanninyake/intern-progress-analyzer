"""
Password Hash Generator for Admin/Supervisor Setup
===================================================
This script generates secure password hashes that can be inserted into the database.
Use this when setting up admin or supervisor accounts manually.

Usage:
    python generate_password_hash.py

Requirements:
    pip install werkzeug
"""

from werkzeug.security import generate_password_hash, check_password_hash
import getpass


def generate_hash():
    """Generate a password hash interactively"""
    print("=" * 60)
    print("Password Hash Generator")
    print("=" * 60)
    print()
    print("This will generate a secure hash for admin/supervisor passwords.")
    print("The hash can be inserted directly into the database.")
    print()
    
    # Get password
    while True:
        password = getpass.getpass("Enter password: ")
        if len(password) < 6:
            print("❌ Password must be at least 6 characters long.")
            continue
        
        confirm = getpass.getpass("Confirm password: ")
        if password != confirm:
            print("❌ Passwords do not match. Try again.")
            continue
        
        break
    
    # Generate hash
    print("\nGenerating secure hash...")
    hashed = generate_password_hash(password)
    
    # Verify hash works
    if check_password_hash(hashed, password):
        print("✅ Hash generated and verified successfully!")
    else:
        print("⚠️ Warning: Hash verification failed!")
        return
    
    print()
    print("=" * 60)
    print("Your Password Hash:")
    print("=" * 60)
    print(hashed)
    print()
    print("=" * 60)
    print("SQL Update Statement:")
    print("=" * 60)
    print()
    
    email = input("Enter user email (e.g., admin@company.com): ").strip()
    
    sql = f"""
UPDATE users 
SET password_hash = '{hashed}' 
WHERE email = '{email}';
"""
    
    print(sql)
    print()
    print("=" * 60)
    print("Instructions:")
    print("=" * 60)
    print("1. Copy the SQL statement above")
    print("2. Run it in your MySQL console or client")
    print("3. User can now login with email + password")
    print()


def batch_generate():
    """Generate multiple hashes at once"""
    print("=" * 60)
    print("Batch Password Hash Generator")
    print("=" * 60)
    print()
    
    users = []
    while True:
        print()
        email = input("Enter email (or press Enter to finish): ").strip()
        if not email:
            break
        
        password = getpass.getpass(f"Enter password for {email}: ")
        if len(password) < 6:
            print("❌ Password must be at least 6 characters.")
            continue
        
        hashed = generate_password_hash(password)
        users.append((email, hashed))
        print(f"✅ Hash generated for {email}")
    
    if not users:
        print("No users entered.")
        return
    
    print()
    print("=" * 60)
    print("SQL Statements:")
    print("=" * 60)
    print()
    
    for email, hashed in users:
        print(f"UPDATE users SET password_hash = '{hashed}' WHERE email = '{email}';")
    
    print()


def main():
    """Main function"""
    print()
    print("╔" + "=" * 58 + "╗")
    print("║" + " " * 10 + "Password Hash Generator" + " " * 25 + "║")
    print("╚" + "=" * 58 + "╝")
    print()
    print("Choose an option:")
    print("1. Generate single hash")
    print("2. Generate multiple hashes")
    print("3. Exit")
    print()
    
    choice = input("Enter choice (1-3): ").strip()
    
    if choice == "1":
        generate_hash()
    elif choice == "2":
        batch_generate()
    elif choice == "3":
        print("Goodbye!")
        return
    else:
        print("Invalid choice.")
        return
    
    print()
    print("=" * 60)
    print("✅ Done!")
    print("=" * 60)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⚠️ Interrupted by user.")
    except Exception as e:
        print(f"\n❌ Error: {e}")
