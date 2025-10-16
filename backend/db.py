# MySQL connection setup
import mysql.connector

def get_db_connection():
    connection = mysql.connector.connect(
        host='localhost',
        user='root',
        password='yourpassword',
        port=3307,
        database='intern_analytics'
    )
    return connection