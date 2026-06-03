import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx      = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request  = ctx.getRequest<Request & { requestId?: string }>();

    const status = exception instanceof HttpException ? exception.getStatus() : 500;

    this.logger.error(JSON.stringify({
      requestId: request['requestId'],
      status,
      path: request.url,
      method: request.method,
      ip: request.ip,
      error: exception instanceof Error ? exception.stack : String(exception),
      timestamp: new Date().toISOString(),
    }));

    const isProd = process.env.NODE_ENV === 'production';

    let message: string | string[];

    if (status >= 500) {
      message = 'Terjadi kesalahan. Silakan coba lagi.';
    } else if (exception instanceof HttpException) {
      const resp = exception.getResponse();
      const raw  = typeof resp === 'string' ? resp : (resp as any).message ?? exception.message;

      if (isProd && status === 401) {
        message = 'Permintaan tidak valid.';
      } else if (isProd && status === 403) {
        message = 'Akses ditolak.';
      } else if (isProd && status === 404 && request.url.startsWith('/auth')) {
        message = 'Permintaan tidak valid.';
      } else {
        message = raw;
      }
    } else {
      message = 'Request tidak valid.';
    }

    response.status(status).json({
      statusCode: status,
      message,
      requestId: request['requestId'],
      timestamp: new Date().toISOString(),
    });
  }
}
