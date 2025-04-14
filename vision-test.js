const vision = require('@google-cloud/vision');

// Create a client
const client = new vision.ImageAnnotatorClient();

async function testVision()
{
  const [result] = await client.safeSearchDetection('https://upload.wikimedia.org/wikipedia/commons/2/22/Turkish_Van_Cat.jpg');
  const detections = result.safeSearchAnnotation;
  console.log('Safe search results:');
  console.log(detections);
}

testVision().catch(console.error);
