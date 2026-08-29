import 'jsr:@supabase/functions-js/edge-runtime.d.ts'

const OPENAI_RESPONSES_URL = 'https://api.openai.com/v1/responses'
const MAX_BASE64_LENGTH = 8_000_000
const ALLOWED_MEDIA_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp'])

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return json({ message: 'Method not allowed.' }, 405)
  }

  const apiKey = Deno.env.get('OPENAI_API_KEY')
  if (!apiKey) {
    return json({ message: 'Food recognition is not configured.' }, 503)
  }

  let body: { image_base64?: unknown; media_type?: unknown }
  try {
    body = await request.json()
  } catch {
    return json({ message: 'Request body must be valid JSON.' }, 400)
  }

  const imageBase64 = body.image_base64
  const mediaType = body.media_type
  if (
    typeof imageBase64 !== 'string' ||
    imageBase64.length === 0 ||
    imageBase64.length > MAX_BASE64_LENGTH ||
    typeof mediaType !== 'string' ||
    !ALLOWED_MEDIA_TYPES.has(mediaType)
  ) {
    return json({ message: 'A supported image is required.' }, 400)
  }

  const openAiResponse = await fetch(OPENAI_RESPONSES_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o-mini',
      store: false,
      input: [
        {
          role: 'user',
          content: [
            {
              type: 'input_text',
              text: 'Identify every visible food or grocery item in this image. Return specific common inventory names such as apple, milk, bread, or rice. Include packaged food based on visible packaging. Do not include plates, containers, furniture, generic categories such as food or fruit, or uncertain objects.',
            },
            {
              type: 'input_image',
              image_url: `data:${mediaType};base64,${imageBase64}`,
              detail: 'low',
            },
          ],
        },
      ],
      text: {
        format: {
          type: 'json_schema',
          name: 'recognized_inventory_foods',
          strict: true,
          schema: {
            type: 'object',
            properties: {
              foods: {
                type: 'array',
                items: { type: 'string' },
                maxItems: 30,
              },
            },
            required: ['foods'],
            additionalProperties: false,
          },
        },
      },
    }),
  })

  if (!openAiResponse.ok) {
    console.error('OpenAI food recognition failed', openAiResponse.status)
    return json({ message: 'Food recognition failed.' }, 502)
  }

  const response = await openAiResponse.json()
  const outputText = response.output
    ?.flatMap((item: { content?: Array<{ type?: string; text?: string }> }) => item.content ?? [])
    .find((content: { type?: string }) => content.type === 'output_text')?.text

  try {
    const parsed = JSON.parse(outputText ?? '')
    const foods = Array.isArray(parsed.foods)
      ? parsed.foods.filter((food: unknown) => typeof food === 'string')
      : []
    return json({ foods })
  } catch {
    return json({ message: 'Food recognition returned invalid data.' }, 502)
  }
})

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}
