"""Sync Lambda function for Moatheny app."""
import json
import os
from datetime import datetime
from decimal import Decimal
import boto3

dynamodb = boto3.resource('dynamodb')

settings_table = dynamodb.Table(os.environ.get('SETTINGS_TABLE', 'moatheny-settings-prod'))
favorites_table = dynamodb.Table(os.environ.get('FAVORITES_TABLE', 'moatheny-favorites-prod'))
tasbih_table = dynamodb.Table(os.environ.get('TASBIH_TABLE', 'moatheny-tasbih-prod'))
prayers_table = dynamodb.Table(os.environ.get('PRAYERS_TABLE', 'moatheny-prayers-prod'))


class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            if obj % 1 == 0:
                return int(obj)
            return float(obj)
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


def sync_data(event, context):
    """
    Full sync endpoint.
    
    Receives local data and returns merged server data.
    Uses last-write-wins for conflict resolution.
    """
    user_id = get_user_id(event)
    if not user_id:
        return response(401, {'error': 'Unauthorized'})
    
    try:
        body = json.loads(event.get('body', '{}'))
        local_data = body.get('data', {})
        last_synced_at = body.get('lastSyncedAt')
        
        result = {
            'settings': None,
            'favorites': [],
            'tasbih': [],
            'prayers': [],
            'syncedAt': datetime.utcnow().isoformat()
        }
        
        if 'settings' in local_data:
            local_settings = local_data['settings']
            local_settings['userId'] = user_id
            
            if local_settings.get('latitude'):
                local_settings['latitude'] = Decimal(str(local_settings['latitude']))
            if local_settings.get('longitude'):
                local_settings['longitude'] = Decimal(str(local_settings['longitude']))
            
            local_settings = {k: v for k, v in local_settings.items() if v is not None}
            settings_table.put_item(Item=local_settings)
        
        settings_result = settings_table.get_item(Key={'userId': user_id})
        result['settings'] = settings_result.get('Item')
        
        if 'favorites' in local_data:
            for fav in local_data['favorites']:
                fav['userId'] = user_id
                fav = {k: v for k, v in fav.items() if v is not None}
                favorites_table.put_item(Item=fav)
        
        from boto3.dynamodb.conditions import Key
        favorites_result = favorites_table.query(
            KeyConditionExpression=Key('userId').eq(user_id)
        )
        result['favorites'] = favorites_result.get('Items', [])
        
        if 'tasbih' in local_data:
            for counter in local_data['tasbih']:
                counter['userId'] = user_id
                counter = {k: v for k, v in counter.items() if v is not None}
                tasbih_table.put_item(Item=counter)
        
        tasbih_result = tasbih_table.query(
            KeyConditionExpression=Key('userId').eq(user_id)
        )
        result['tasbih'] = tasbih_result.get('Items', [])
        
        if 'prayers' in local_data:
            for prayer in local_data['prayers']:
                prayer['userId'] = user_id
                prayer = {k: v for k, v in prayer.items() if v is not None}
                prayers_table.put_item(Item=prayer)
        
        prayers_result = prayers_table.query(
            KeyConditionExpression=Key('userId').eq(user_id),
            ScanIndexForward=False,
            Limit=30
        )
        result['prayers'] = prayers_result.get('Items', [])
        
        return response(200, result)
        
    except json.JSONDecodeError:
        return response(400, {'error': 'Invalid JSON'})
    except Exception as e:
        print(f"Error syncing data: {e}")
        return response(500, {'error': 'Internal server error'})
