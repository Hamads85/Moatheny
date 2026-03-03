"""Favorites Lambda functions for Moatheny app."""
import json
import os
import uuid
from datetime import datetime
import boto3
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ.get('FAVORITES_TABLE', 'moatheny-favorites-prod'))


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
        'body': json.dumps(body, ensure_ascii=False)
    }


def get_favorites(event, context):
    """Get all favorites for a user."""
    user_id = get_user_id(event)
    if not user_id:
        return response(401, {'error': 'Unauthorized'})
    
    try:
        query_params = event.get('queryStringParameters') or {}
        item_type = query_params.get('type')
        
        result = table.query(
            KeyConditionExpression=Key('userId').eq(user_id)
        )
        
        favorites = result.get('Items', [])
        
        if item_type:
            favorites = [f for f in favorites if f.get('type') == item_type]
        
        return response(200, {'favorites': favorites})
    except Exception as e:
        print(f"Error getting favorites: {e}")
        return response(500, {'error': 'Internal server error'})


def save_favorite(event, context):
    """Save a new favorite."""
    user_id = get_user_id(event)
    if not user_id:
        return response(401, {'error': 'Unauthorized'})
    
    try:
        body = json.loads(event.get('body', '{}'))
        
        item_type = body.get('type')
        if item_type not in ['surah', 'ayah', 'zikr', 'reciter']:
            return response(400, {'error': 'Invalid type. Must be: surah, ayah, zikr, or reciter'})
        
        item_id = body.get('itemId') or str(uuid.uuid4())
        
        item = {
            'userId': user_id,
            'itemId': item_id,
            'type': item_type,
            'referenceId': body.get('referenceId'),
            'title': body.get('title'),
            'subtitle': body.get('subtitle'),
            'createdAt': datetime.utcnow().isoformat()
        }
        
        item = {k: v for k, v in item.items() if v is not None}
        
        table.put_item(Item=item)
        
        return response(201, {'message': 'Favorite saved', 'favorite': item})
    except json.JSONDecodeError:
        return response(400, {'error': 'Invalid JSON'})
    except Exception as e:
        print(f"Error saving favorite: {e}")
        return response(500, {'error': 'Internal server error'})


def delete_favorite(event, context):
    """Delete a favorite."""
    user_id = get_user_id(event)
    if not user_id:
        return response(401, {'error': 'Unauthorized'})
    
    try:
        item_id = event.get('pathParameters', {}).get('itemId')
        if not item_id:
            return response(400, {'error': 'itemId is required'})
        
        table.delete_item(
            Key={
                'userId': user_id,
                'itemId': item_id
            }
        )
        
        return response(200, {'message': 'Favorite deleted'})
    except Exception as e:
        print(f"Error deleting favorite: {e}")
        return response(500, {'error': 'Internal server error'})
