const CACHE_VERSION = "charity-station-v1";

self.addEventListener("install", (event) => {
	self.skipWaiting();
});

self.addEventListener("activate", (event) => {
	event.waitUntil(self.clients.claim());
});

function withRequiredHeaders(response) {
	const headers = new Headers(response.headers);
	headers.set("Cross-Origin-Opener-Policy", "same-origin");
	headers.set("Cross-Origin-Embedder-Policy", "require-corp");
	headers.set("Cross-Origin-Resource-Policy", "cross-origin");

	const csp = headers.get("Content-Security-Policy");
	if (csp) {
		headers.set(
			"Content-Security-Policy",
			csp.replace(/script-src([^;]*)/i, (match) => (
				match.includes("wasm-unsafe-eval") ? match : `${match} 'wasm-unsafe-eval' blob:`
			))
		);
	} else {
		headers.set(
			"Content-Security-Policy",
			"default-src 'self' https: data: blob:; script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' https: blob:; worker-src 'self' blob:; child-src 'self' blob:; connect-src 'self' https: data: blob:; img-src 'self' https: data: blob:; style-src 'self' 'unsafe-inline' https:; media-src 'self' https: data: blob:;"
		);
	}

	return new Response(response.body, {
		status: response.status,
		statusText: response.statusText,
		headers,
	});
}

self.addEventListener("fetch", (event) => {
	if (event.request.method !== "GET") {
		return;
	}

	event.respondWith(
		fetch(event.request, { cache: "no-store" })
			.then(withRequiredHeaders)
			.catch(() => caches.open(CACHE_VERSION).then((cache) => cache.match(event.request)))
	);
});
