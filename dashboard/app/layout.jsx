import './globals.css';

export const metadata = {
  title: 'ReflectScan Dashboard',
  description:
    'Live retroreflectivity status across the national highway network — '
    + 'NHAI Innovation Hackathon 2026 prototype.',
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <head>
        <link
          rel="stylesheet"
          href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"
          integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY="
          crossOrigin=""
        />
      </head>
      <body>{children}</body>
    </html>
  );
}
