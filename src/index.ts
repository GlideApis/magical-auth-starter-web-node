import { randomUUID } from 'crypto';
import express from 'express';
import { GlideClient } from 'glide-sdk';

const PORT = process.env.PORT || 4567;

const glideClient = new GlideClient();
const stateCache: Record<string, string> = {};

const app = express();
app.use(express.json());
app.use(express.static(__dirname + '/static'));

app.get('/', (req, res) => {
    res.sendFile(__dirname + '/static/index.html');
});

app.post('/api/start-verification', async (req, res) => {
    const { phoneNumber } = req.body;
    console.log('Start Auth');
    try {
        const sessionId = randomUUID();
        stateCache[sessionId] = phoneNumber;
        const authRes = await glideClient.magicAuth.startAuth({
            phoneNumber,
            state: sessionId,
            redirectUrl: process.env.MAGIC_REDIRECT_URI || `http://localhost:${PORT}/`,
        });
        res.json(authRes);
    } catch (error) {
        console.error(error);
        res.status(400).json({ error: 'Error starting auth' });
    }
});

app.post('/api/check-verification', async (req, res) => {
    const { phoneNumber, token } = req.body;
    console.log('Check Auth');
    try {
        const checkRes = await glideClient.magicAuth.verifyAuth({
            phoneNumber,
            token,
        });
        res.json(checkRes);
    } catch (error) {
        console.error(error);
        res.status(400).json({ error: 'Error verifying token' });
    }
});

app.post('/api/get-session', async (req, res) => {
    const { state } = req.body;
    console.log('Get Session');
    try {
        const phoneNumber = stateCache[state];
        res.json({ phoneNumber });
    } catch (error) {
        console.error(error);
        res.status(400).json({ error: 'Error getting session' });
    }
});

app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});
