from flask import Flask
from flask_cors import CORS

# Import route blueprints
# Ex: from routes.intern_routes import intern_bp

def create_app():
    app = Flask(__name__)

    # Set up CORS
    CORS(app, origins=app.config['CORS_ORIGINS'])

    # Register blueprints for routes
    # Ex: app.register_blueprint(user_bp)

    return app

# Create the Flask application
app = create_app()

if __name__ == "__main__":
    app.run(debug=True)