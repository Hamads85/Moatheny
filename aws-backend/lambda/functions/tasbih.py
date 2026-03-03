"""Tasbih (counter) Lambda functions for Moatheny app."""
import json
import os
import uuid
from datetime import datetime
from decimal import Decimal
import boto3
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ.get('TASBIH_TABLE', 'moatheny-tasbih-prod'))


class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return int(obj)
        return super().default(obj)


def get_user_id(event):
    """Extract user ID from Cognito authorizer."""
    try:
        return event['requestContext']['authorizer']['claims']['sub']
    except (KeyError, TypeError):
        return None


def response(status_code, body):
    """Create API Gateway response."""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        },
        'body': json.dumps(body, cls=DecimalEncoder, ensure_ascii=False)
    }


def get_tasbih(event, context):
    """Get all tasbih counters for a user."""
    user_id = get_user_id(event)
    if not user_id:
        return response(401, {'error': 'Unauthorized'})
    
    try:
        result = table.query(
            KeyConditionExpression=Key('userId').eq(user_id)
        )
        
        counters = result.get('Items', [])
        
        return response(200, {'counters': counters})
    except Exception as e:
        print(f"Error getting tasbih: {e}")
        return response(500, {'error': 'Internal server error'})


def save_tasbih(event, context):
    """Save or update a tasbih counter."""
    user_id = get_user_id(event)
    if not user_id:
        return response(401, {'error': 'Unauthorized'})
    
    try:
        body = json.loads(event.get('body', '{}'))
        
        counter_id = body.get('counterId') or str(uuid.uuid4())
        
        item = {
            'userId': user_id,
            'counterId': counter_id,
            'title': body.get('title', 'سبحان الله'),
            'target': body.get('target', 33),
            'current': body.get('current', 0),
            'updatedAt': datetime.utcnow().isoformat()
        }
        
        table.put_item(Item=item)
        
        return response(200, {'message': 'Counter saved', 'counter': item})
    except json.JSONDecodeError:
        return response(400, {'error': 'Invalid JSON'})
    except Exception as e:
        print(f"Error saving tasbih: {e}")
        return response(500, {'error': 'Internal server error'})
