from flask import Flask, jsonify
from flask_cors import CORS

# Import blueprints
from routes.auth import auth_routes
from routes.intern import intern_routes
from routes.supervisor import supervisor_routes
from routes.project import project_routes
from routes.ai_reports import ai_routes
from routes.admin import admin_routes
from routes.forgot_password import forgot_password_routes
from routes.test_ai import test_routes

app = Flask(__name__)
CORS(app)  # Allow cross-origin requests (from Flutter frontend)

# Register blueprints
app.register_blueprint(auth_routes)
app.register_blueprint(intern_routes)
app.register_blueprint(supervisor_routes)
app.register_blueprint(project_routes)
app.register_blueprint(ai_routes, url_prefix='/api/ai')
app.register_blueprint(admin_routes)
app.register_blueprint(forgot_password_routes)
app.register_blueprint(test_routes, url_prefix='/api')

# Root endpoint
@app.route('/')
def index():
    return jsonify({'success': True, 'message': 'Intern Progress Analyzer API is running!'})

# Error handling
@app.errorhandler(404)
def not_found(error):
    return jsonify({'success': False, 'message': 'Endpoint not found'}), 404

@app.errorhandler(500)
def server_error(error):
    return jsonify({'success': False, 'message': 'Internal server error'}), 500

# Run the Flask app
if __name__ == '__main__':
    app.run(debug=True)
