import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { IoAdapter } from '@nestjs/platform-socket.io';
import { NestExpressApplication } from '@nestjs/platform-express';
import { json, urlencoded } from 'express';
import { join } from 'path';
import * as fs from 'fs';
import helmet from 'helmet';

const hpp = require('hpp') as () => any;
import { v4 as uuidv4 } from 'uuid';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './filters/all-exceptions.filter';

const SUSPICIOUS_PATTERNS = [
  /(\%27)|(\')|(\-\-)|(\%23)/i,   // SQL injection basics
  /<script[\s>]/i,                  // XSS script tag
  /\.\.[\/\\]/,                     // Path traversal
  /union\s+select/i,                // SQL union
  /exec\s*\(.*xp_/i,               // SQL exec
  /SLEEP\s*\(\d/i,                  // SQL time-based
  /javascript:/i,                   // JS injection
];

async function bootstrap() {
  const uploadsDir = join(process.cwd(), 'uploads', 'drivers');
  if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir, { recursive: true });
  }

  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    bodyParser: false, // kita set sendiri agar bisa batasi ukuran
  });

  const isProd = process.env.NODE_ENV === 'production';

  // ── Payload size limit (1 MB) ─────────────────────────────────────────────
  app.use(json({ limit: '1mb' }));
  app.use(urlencoded({ extended: true, limit: '1mb' }));

  // ── Security headers (Helmet) ─────────────────────────────────────────────
  app.use(helmet({
    contentSecurityPolicy: false,       // REST API tidak butuh CSP
    crossOriginEmbedderPolicy: true,
    crossOriginOpenerPolicy: true,
    crossOriginResourcePolicy: { policy: 'same-origin' },
    dnsPrefetchControl: { allow: false },
    frameguard: { action: 'deny' },
    hidePoweredBy: true,
    hsts: { maxAge: 31536000, includeSubDomains: true },
    ieNoOpen: true,
    noSniff: true,
    originAgentCluster: true,
    permittedCrossDomainPolicies: { permittedPolicies: 'none' },
    referrerPolicy: { policy: 'no-referrer' },
    xssFilter: true,
  }));

  // ── Additional headers ────────────────────────────────────────────────────
  app.use((_req: any, res: any, next: any) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Frame-Options', 'DENY');
    res.setHeader('X-XSS-Protection', '1; mode=block');
    res.setHeader('Referrer-Policy', 'no-referrer');
    res.setHeader('Permissions-Policy', 'geolocation=()');
    next();
  });

  // ── Anti parameter pollution ──────────────────────────────────────────────
  app.use(hpp());

  // ── Request ID tracker ────────────────────────────────────────────────────
  app.use((req: any, res: any, next: any) => {
    req['requestId'] = uuidv4();
    res.setHeader('X-Request-ID', req['requestId']);
    next();
  });

  // ── Request logger (no sensitive data) ───────────────────────────────────
  app.use((req: any, res: any, next: any) => {
    const start = Date.now();
    res.on('finish', () => {
      const log = {
        requestId: req['requestId'],
        method: req.method,
        path: req.path,
        ip: req.ip,
        status: res.statusCode,
        ms: Date.now() - start,
        ts: new Date().toISOString(),
      };
      if (res.statusCode >= 400) {
        console.error('[REQ_ERR]', JSON.stringify(log));
      }
    });
    next();
  });

  // ── Suspicious activity detector (query & params only) ────────────────────
  app.use((req: any, res: any, next: any) => {
    const check = JSON.stringify({ q: req.query, p: req.params });
    if (SUSPICIOUS_PATTERNS.some((rx) => rx.test(check))) {
      console.error('[SUSPICIOUS]', {
        ip: req.ip,
        method: req.method,
        path: req.path,
        ts: new Date().toISOString(),
      });
      return res.status(400).json({ statusCode: 400, message: 'Request tidak valid.' });
    }
    next();
  });

  // ── CORS (whitelist via env) ──────────────────────────────────────────────
  const allowedOrigins = (process.env.CORS_ORIGINS ?? '')
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean);

  app.enableCors({
    origin: (origin: string | undefined, cb: (e: Error | null, ok?: boolean) => void) => {
      // Mobile apps tidak kirim Origin — izinkan
      if (!origin || allowedOrigins.length === 0 || allowedOrigins.includes(origin)) {
        cb(null, true);
      } else {
        cb(new Error('Not allowed by CORS'));
      }
    },
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true,
    maxAge: 3600,
  });

  app.useStaticAssets(join(process.cwd(), 'uploads'), { prefix: '/uploads' });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  // ── Global exception filter ───────────────────────────────────────────────
  app.useGlobalFilters(new AllExceptionsFilter());

  // ── Swagger (hanya non-production) ───────────────────────────────────────
  if (!isProd) {
    const config = new DocumentBuilder()
      .setTitle('Lungo API')
      .setDescription('API dokumentasi untuk aplikasi ojek online Lungo')
      .setVersion('1.0')
      .addBearerAuth()
      .build();
    const document = SwaggerModule.createDocument(app, config);
    SwaggerModule.setup('api', app, document);
    console.log(`Swagger docs: http://localhost:${process.env.PORT ?? 3000}/api`);
  }

  app.useWebSocketAdapter(new IoAdapter(app));

  app.use('/health', (_req: any, res: any) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
  });

  const port = process.env.PORT ?? 3000;
  await app.listen(port);
  console.log(`Lungo API berjalan di http://localhost:${port}`);
}
bootstrap();
