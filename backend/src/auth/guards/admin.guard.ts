import {
  Injectable,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
} from '@nestjs/common';

@Injectable()
export class AdminGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    const user = request.user as { sub?: string; role?: string } | undefined;
    if (!user || user.role !== 'ADMIN') {
      throw new ForbiddenException('Akses ditolak: hanya untuk admin');
    }
    return true;
  }
}
