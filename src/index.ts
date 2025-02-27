import { randomUUID } from 'crypto';
import express from 'express';
import { GlideClient } from 'glide-sdk';

enum FallbackVerificationChannel {
    SMS = 'SMS',
    EMAIL = 'EMAIL',
    NO_FALLBACK = 'NO_FALLBACK'
}

interface SessionData {
    phoneNumber: string;
    status: 'pending' | 'verified' | 'failed' | 'error' | 'callback_received';
    deviceIpAddress: string;
    error?: string;
}

const PORT = process.env.PORT || 4567;

const glideClient = new GlideClient();
const stateCache: Record<string, SessionData> = {};

// Helper function to get client IP
function getClientIp(req: express.Request): string {
    const forwardedFor = req.headers['x-forwarded-for'];
    console.log(forwardedFor);
    if (forwardedFor && typeof forwardedFor === 'string') {
        return forwardedFor.split(',')[0].trim();
    }
    return req.ip || req.socket.remoteAddress || 'unknown';
}

const app = express();
app.use(express.json());
app.use(express.static(__dirname + '/static'));

app.get('/', (req, res) => {
    res.sendFile(__dirname + '/static/index.html');
});

app.post('/api/start-verification', async (req, res) => {
    const { phoneNumber } = req.body;
    const deviceIpAddress = getClientIp(req);
    console.log(`Start Auth for ${phoneNumber} from IP ${deviceIpAddress}`);
    
    try {
        const sessionId = randomUUID();
        stateCache[sessionId] = {
            phoneNumber,
            status: 'pending',
            deviceIpAddress
        };
        
        const authRes = await glideClient.magicAuth.startAuth({
            phoneNumber,
            state: sessionId,
            redirectUrl: process.env.MAGIC_REDIRECT_URI || `http://localhost:${PORT}/`,
            deviceIpAddress,
            fallbackChannel: FallbackVerificationChannel.NO_FALLBACK
        });
        res.json(authRes);
    } catch (error) {
        console.error(error);
        res.status(400).json({ error: error instanceof Error ? error.message : 'Error starting auth' });
    }
});

app.post('/api/check-verification', async (req, res) => {
    const { phoneNumber, token } = req.body;
    const deviceIpAddress = getClientIp(req);
    console.log(`Check Auth for ${phoneNumber} from IP ${deviceIpAddress}`);
    
    try {
        const checkRes = await glideClient.magicAuth.verifyAuth({
            phoneNumber,
            token,
            deviceIpAddress
        });
        res.json(checkRes);
    } catch (error) {
        console.error(error);
        res.status(400).json({ error: error instanceof Error ? error.message : 'Error verifying token' });
    }
});

app.post('/api/get-session', async (req, res) => {
    const { state } = req.body;
    console.log('Get Session');
    
    try {
        if (!stateCache[state]) {
            return res.status(404).json({ error: 'Session not found' });
        }

        const sessionData = stateCache[state];
        res.json({
            phoneNumber: sessionData.phoneNumber,
            status: sessionData.status
        });
    } catch (error) {
        console.error(error);
        res.status(400).json({ error: error instanceof Error ? error.message : 'Error getting session' });
    }
});

app.get('/callback', (req, res) => {
    const state = req.query.state as string;
    const error = req.query.error as string;

    try {
        if (!stateCache[state]) {
            return res.status(400).json({ error: 'Invalid state parameter' });
        }

        if (error) {
            stateCache[state].status = 'error';
            stateCache[state].error = error;
        } else {
            stateCache[state].status = 'callback_received';
        }

        res.sendFile(__dirname + '/static/index.html');
    } catch (error) {
        console.error(error);
        res.status(400).json({ error: error instanceof Error ? error.message : 'Error processing callback' });
    }
});

app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});
