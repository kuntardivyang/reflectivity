/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  async rewrites() {
    // Proxy /api/* to FastAPI so the browser doesn't hit CORS in dev.
    return [
      {
        source: '/api/:path*',
        destination: 'https://reflectivity-production.up.railway.app/api/:path*',
      },
    ];
  },
};

module.exports = nextConfig;
