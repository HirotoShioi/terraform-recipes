import { APIGatewayEvent, ProxyResult } from 'aws-lambda'

const checkEnvs = () => {
  const envs = ['ENV1']
  const missingEnvs = envs.filter((env) => !process.env[env])
  if (missingEnvs.length > 0) {
    throw new Error(`Missing envs: ${missingEnvs.join(', ')}`)
  }
}

export const handler = async (event: APIGatewayEvent): Promise<ProxyResult> => {
  checkEnvs()
  const name = event.queryStringParameters?.name || 'World'
  return {
    statusCode: 200,
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      message: `Hello ${name}!`,
    }),
  }
}
