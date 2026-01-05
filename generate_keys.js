// generate_keys.js
// Run: node generate_keys.js

const jose = require('jose');
const crypto = require('crypto');

async function generateKeys() {
  const alg = 'RS256';
  
  // Generate a random KID
  const kid = `powersync-${crypto.randomBytes(5).toString('hex')}`;
  
  console.log('🔑 Generating RS256 Key Pair...\n');
  
  // Generate key pair
  const { publicKey, privateKey } = await jose.generateKeyPair(alg, {
    extractable: true,
  });
  
  // Export as JWK
  const privateJwk = {
    ...(await jose.exportJWK(privateKey)),
    alg,
    kid,
    use: 'sig',
  };
  
  const publicJwk = {
    ...(await jose.exportJWK(publicKey)),
    alg,
    kid,
    use: 'sig',
  };
  
  console.log('=' .repeat(80));
  console.log('✅ KEYS GENERATED SUCCESSFULLY');
  console.log('=' .repeat(80));
  
  console.log('\n📋 PRIVATE KEY (Keep this SECRET in your Flutter app):');
  console.log('=' .repeat(80));
  console.log(JSON.stringify(privateJwk, null, 2));
  
  console.log('\n\n📋 PUBLIC KEY (Upload to PowerSync Dashboard):');
  console.log('=' .repeat(80));
  console.log(JSON.stringify(publicJwk, null, 2));
  
  console.log('\n\n🔗 JWKS FORMAT (For PowerSync JWKS URI):');
  console.log('=' .repeat(80));
  const jwks = {
    keys: [publicJwk]
  };
  console.log(JSON.stringify(jwks, null, 2));
  
  console.log('\n\n📝 NEXT STEPS:');
  console.log('=' .repeat(80));
  console.log('1. Copy the PRIVATE KEY to your Flutter app');
  console.log('2. In PowerSync Dashboard → Client Auth:');
  console.log('   - Enable "Enable development tokens"');
  console.log('   - Set JWKS URI to your hosted JWKS endpoint');
  console.log('   - OR paste the PUBLIC KEY directly');
  console.log('3. Update your KID in Flutter: ' + kid);
  console.log('=' .repeat(80));
}

generateKeys().catch(console.error);

// Install: npm install jose
// Run: node generate_keys.js