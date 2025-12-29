import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { SignJWT, importPKCS8 } from "https://deno.land/x/jose@v4.14.4/index.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Generate Google OAuth2 access token using service account
async function getGoogleAccessToken(serviceAccount: any): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  
  // Import the private key
  const privateKey = await importPKCS8(
    serviceAccount.private_key,
    'RS256'
  )
  
  // Create the JWT
  const jwt = await new SignJWT({
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/firebase.messaging'
  })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .sign(privateKey)
  
  // Exchange JWT for access token
  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })
  
  const tokenData = await tokenResponse.json()
  
  if (!tokenData.access_token) {
    throw new Error(`Failed to get access token: ${JSON.stringify(tokenData)}`)
  }
  
  return tokenData.access_token
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Parse request body
    const { title, body, data, recipient_roles, recipient_user_ids, event_type } = await req.json()

    console.log(`Processing notification: ${title} for roles: ${recipient_roles || 'none'} or users: ${recipient_user_ids || 'none'}`)

    // 1. Get FCM Tokens from database
    let query = supabaseClient
      .from('fcm_tokens')
      .select(`
        fcm_token,
        user_id,
        users!inner(role)
      `)
      .eq('is_active', true)

    if (recipient_roles && recipient_roles.length > 0) {
      query = query.in('users.role', recipient_roles)
    }
    
    if (recipient_user_ids && recipient_user_ids.length > 0) {
      query = query.in('user_id', recipient_user_ids)
    }

    const { data: tokensData, error: tokensError } = await query

    if (tokensError) {
      console.error('Error fetching tokens:', tokensError)
      throw tokensError
    }
    
    if (!tokensData || tokensData.length === 0) {
      console.log('No active FCM tokens found for recipients')
      return new Response(JSON.stringify({ message: 'No active FCM tokens found for recipients' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    const tokens = tokensData.map(t => t.fcm_token)
    console.log(`Found ${tokens.length} tokens to notify.`)

    // 2. Get Google Access Token using Service Account
    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
    if (!serviceAccountJson) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT secret not configured')
    }
    
    const serviceAccount = JSON.parse(serviceAccountJson)
    const accessToken = await getGoogleAccessToken(serviceAccount)

    // 3. Send notifications via FCM v1 API
    const projectId = serviceAccount.project_id
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`

    const sendResults = await Promise.all(tokens.map(async (fcmToken) => {
      try {
        const response = await fetch(fcmUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${accessToken}`,
          },
          body: JSON.stringify({
            message: {
              token: fcmToken,
              notification: {
                title,
                body,
              },
              data: data ? Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])) : {},
              android: {
                priority: 'high',
                notification: {
                  channel_id: 'scm_notifications',
                }
              }
            },
          }),
        })

        const result = await response.json()
        console.log(`FCM response for token ${fcmToken.substring(0, 20)}...: `, result)
        return { success: response.ok, result, token: fcmToken }
      } catch (err) {
        console.error(`Error sending to token ${fcmToken.substring(0, 20)}...: `, err)
        return { success: false, error: err.message, token: fcmToken }
      }
    }))

    const successCount = sendResults.filter(r => r.success).length
    const failureCount = sendResults.length - successCount

    console.log(`Notifications sent: ${successCount} success, ${failureCount} failed`)

    // 4. Log the notification
    try {
      await supabaseClient.from('notification_logs').insert({
        notification_type: event_type || 'generic',
        title,
        body,
        data,
        is_sent: successCount > 0,
        sent_at: new Date().toISOString(),
        user_id: tokensData[0].user_id 
      })
    } catch (logError) {
      console.error('Error logging notification:', logError)
    }

    return new Response(JSON.stringify({ 
      success: true, 
      sent: successCount, 
      failed: failureCount 
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    console.error('Error in notify function:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
