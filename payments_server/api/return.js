// GET /api/return  Where Paymob sends the customer after checkout. Nothing
// here is trusted (the signed webhook decides); it just says what to do next.
export default function handler(req, res) {
  const ok = req.query?.success === 'true';
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.status(200).send(`<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Gulf Limousine Travel</title>
<style>body{font-family:system-ui,sans-serif;background:#000;color:#fff;display:flex;
min-height:100vh;align-items:center;justify-content:center;margin:0;text-align:center}
main{padding:24px;max-width:420px}h1{color:#FF8C00}</style></head>
<body><main><h1>${ok ? 'Payment complete' : 'Payment not completed'}</h1>
<p>${ok ? 'You can close this page and return to the app. Your booking updates in a few seconds.'
       : 'No money was taken. Close this page and return to the app to try again.'}</p>
</main></body></html>`);
}
