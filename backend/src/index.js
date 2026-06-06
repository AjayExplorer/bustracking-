// Durable Object for WebSocket routing and broadcasting
export class LocationBroadcaster {
  constructor(state, env) {
    this.state = state;
    this.env = env;
    this.sessions = [];
  }

  async fetch(request) {
    const url = new URL(request.url);
    
    // Handle WebSocket upgrade
    if (request.headers.get("Upgrade") === "websocket") {
      const pair = new WebSocketPair();
      const [client, server] = Object.values(pair);

      await this.handleSession(server);

      return new Response(null, { status: 101, webSocket: client });
    }

    // Handle broadcast POST from HTTP API
    if (request.method === "POST") {
      try {
        const data = await request.json();
        this.broadcast(data);
        return new Response("OK");
      } catch (err) {
        return new Response("Invalid JSON", { status: 400 });
      }
    }

    return new Response("Not found", { status: 404 });
  }

  async handleSession(webSocket) {
    webSocket.accept();
    this.sessions.push(webSocket);

    webSocket.addEventListener("message", async (msg) => {
      // If client (e.g. driver) sends location directly via WebSocket
      try {
        const data = JSON.parse(msg.data);
        this.broadcast(data);
      } catch (e) {
        webSocket.send(JSON.stringify({ error: "Invalid JSON format" }));
      }
    });

    const cleanup = () => {
      this.sessions = this.sessions.filter(s => s !== webSocket);
    };

    webSocket.addEventListener("close", cleanup);
    webSocket.addEventListener("error", cleanup);
  }

  broadcast(data) {
    const message = JSON.stringify(data);
    
    // Send to all connected clients
    this.sessions.forEach(session => {
      try {
        session.send(message);
      } catch (e) {
        // Remove dead session
        this.sessions = this.sessions.filter(s => s !== session);
      }
    });
  }
}

// Worker fetch handler
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;

    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    };

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    try {
      // 1. GET /api/buses
      if (path === "/api/buses" && request.method === "GET") {
        const { results } = await env.DB.prepare("SELECT * FROM buses").all();
        return new Response(JSON.stringify(results), {
          headers: { "Content-Type": "application/json", ...corsHeaders },
        });
      }

      // 2. GET /api/buses/:id/stops
      const stopsMatch = path.match(/^\/api\/buses\/(\d+)\/stops$/);
      if (stopsMatch && request.method === "GET") {
        const busId = parseInt(stopsMatch[1]);
        const { results } = await env.DB.prepare(
          "SELECT * FROM stops WHERE bus_id = ? ORDER BY stop_order ASC"
        ).bind(busId).all();
        return new Response(JSON.stringify(results), {
          headers: { "Content-Type": "application/json", ...corsHeaders },
        });
      }

      // 3. POST /api/location/update
      if (path === "/api/location/update" && request.method === "POST") {
        const data = await request.json();
        const { busId, latitude, longitude, speed } = data;

        if (busId === undefined || latitude === undefined || longitude === undefined || speed === undefined) {
          return new Response("Missing parameters", { status: 400, headers: corsHeaders });
        }

        // Upsert live location into SQLite D1
        await env.DB.prepare(
          `INSERT INTO live_locations (bus_id, latitude, longitude, speed, updated_at) 
           VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
           ON CONFLICT(bus_id) DO UPDATE SET 
             latitude = excluded.latitude, 
             longitude = excluded.longitude, 
             speed = excluded.speed, 
             updated_at = CURRENT_TIMESTAMP`
        ).bind(busId, latitude, longitude, speed).run();

        // Forward to Durable Object for live WebSocket broadcast
        const doId = env.LOCATION_DO.idFromName(busId.toString());
        const doStub = env.LOCATION_DO.get(doId);
        
        await doStub.fetch(new Request(`http://do/ws`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            busId,
            latitude,
            longitude,
            speed,
            updatedAt: new Date().toISOString()
          })
        }));

        return new Response(JSON.stringify({ success: true }), {
          headers: { "Content-Type": "application/json", ...corsHeaders },
        });
      }

      // 4. GET /api/location/:busId
      const locationMatch = path.match(/^\/api\/location\/(\d+)$/);
      if (locationMatch && request.method === "GET") {
        const busId = parseInt(locationMatch[1]);
        const loc = await env.DB.prepare(
          "SELECT * FROM live_locations WHERE bus_id = ? LIMIT 1"
        ).bind(busId).first();

        if (!loc) {
          return new Response(JSON.stringify({ error: "Location not found" }), {
            status: 404,
            headers: { "Content-Type": "application/json", ...corsHeaders },
          });
        }

        return new Response(JSON.stringify(loc), {
          headers: { "Content-Type": "application/json", ...corsHeaders },
        });
      }

      // 5. WebSocket /ws/location/:busId
      const wsMatch = path.match(/^\/ws\/location\/(\d+)$/);
      if (wsMatch) {
        const busId = wsMatch[1];
        const doId = env.LOCATION_DO.idFromName(busId);
        const doStub = env.LOCATION_DO.get(doId);
        
        return doStub.fetch(request);
      }

      return new Response("Not Found", { status: 404, headers: corsHeaders });
    } catch (err) {
      return new Response(JSON.stringify({ error: err.message }), {
        status: 500,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }
  }
}
