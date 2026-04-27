var _a;
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
var apiTarget = (_a = process.env.VITE_DEV_API_TARGET) !== null && _a !== void 0 ? _a : "http://localhost:3000";
export default defineConfig({
    plugins: [react()],
    server: {
        host: "0.0.0.0",
        port: 5173,
        proxy: {
            "/api": {
                target: apiTarget,
                changeOrigin: true
            }
        }
    }
});
