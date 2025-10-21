"""
Test script to verify AI report generation functionality
"""
import requests
import json

# Test configuration
BASE_URL = "http://127.0.0.1:5000"
AI_BASE_URL = f"{BASE_URL}/api/ai"

def test_login():
    """Test login to get auth token"""
    login_data = {
        "email": "supervisor@example.com",
        "password": "password123"
    }
    
    try:
        response = requests.post(f"{BASE_URL}/login", json=login_data)
        if response.status_code == 200:
            data = response.json()
            if data.get('success'):
                return data.get('token')
            else:
                print(f"Login failed: {data.get('message')}")
        else:
            print(f"Login request failed: {response.status_code}")
    except Exception as e:
        print(f"Login error: {e}")
    
    return None

def test_ai_providers(token):
    """Test AI providers endpoint"""
    headers = {"x-access-token": token}
    
    try:
        response = requests.get(f"{AI_BASE_URL}/providers", headers=headers)
        print(f"AI Providers Response: {response.status_code}")
        print(f"Response: {response.text}")
        
        if response.status_code == 200:
            data = response.json()
            if data.get('success'):
                providers = data.get('providers', [])
                print(f"Available providers: {len(providers)}")
                for provider in providers:
                    print(f"  - {provider['display_name']}: {'Available' if provider['available'] else 'Unavailable'}")
                return providers
        
    except Exception as e:
        print(f"AI providers test error: {e}")
    
    return []

def test_generate_report(token, provider_name="ollama"):
    """Test AI report generation"""
    headers = {"x-access-token": token}
    
    # Sample request data
    report_data = {
        "provider": provider_name,
        "intern_id": 1,  # Assuming intern ID 1 exists
        "report_type": "weekly",
        "use_fallback": True
    }
    
    try:
        response = requests.post(f"{AI_BASE_URL}/generate-report", 
                               headers=headers, 
                               json=report_data)
        print(f"Generate Report Response: {response.status_code}")
        print(f"Response: {response.text}")
        
        if response.status_code == 200:
            data = response.json()
            if data.get('success', True):
                print("✅ Report generated successfully!")
                report_content = data.get('content', {})
                print(f"Summary: {report_content.get('summary', 'No summary')[:100]}...")
                return True
            else:
                print(f"❌ Report generation failed: {data.get('error')}")
        else:
            print(f"❌ Request failed with status {response.status_code}")
            
    except Exception as e:
        print(f"Generate report error: {e}")
    
    return False

def main():
    print("🧪 Testing AI Report Generation System")
    print("=" * 50)
    
    # Step 1: Login
    print("1. Testing login...")
    token = test_login()
    if not token:
        print("❌ Login failed - cannot continue tests")
        return
    print("✅ Login successful")
    
    # Step 2: Test AI providers
    print("\n2. Testing AI providers endpoint...")
    providers = test_ai_providers(token)
    if not providers:
        print("❌ No providers available")
        return
    
    # Step 3: Test report generation with available providers
    print("\n3. Testing report generation...")
    available_providers = [p for p in providers if p['available']]
    
    if not available_providers:
        print("❌ No available providers for testing")
        return
    
    for provider in available_providers:
        print(f"\nTesting with {provider['display_name']}...")
        success = test_generate_report(token, provider['name'])
        if success:
            print(f"✅ {provider['display_name']} test passed")
            break
        else:
            print(f"❌ {provider['display_name']} test failed")
    
    print("\n🎉 AI Testing Complete!")

if __name__ == "__main__":
    main()