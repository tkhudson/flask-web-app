from flask import Flask, render_template

# Create a Flask application instance
app = Flask(__name__)

# Define routes and corresponding view functions
@app.route('/')
def home():
    return render_template('index.html')

@app.route('/')
def blog():
    return render_template('blog.html')

# Run the Flask application
if __name__ == '__main__':
    app.run(debug=True)
