"""
Simple test route to verify AI system integration
"""
from flask import Blueprint, jsonify

test_routes = Blueprint('test_routes', __name__)

@test_routes.route('/test-ai', methods=['GET'])
def test_ai_system():
    """Simple test endpoint for AI system"""
    try:
        # Import AI manager here to avoid circular imports
        from utils.ai_providers.ai_manager import AIManager
        
        ai_manager = AIManager()
        providers = ai_manager.get_available_providers()
        
        return jsonify({
            'success': True,
            'message': 'AI system is working',
            'providers_count': len(providers),
            'providers': [p['name'] for p in providers]
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500