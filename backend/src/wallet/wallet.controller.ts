import {
  Controller, Get, Post, Body, Req, UseGuards, Query,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { Request } from 'express';
import { WalletService } from './wallet.service';
import { JwtGuard } from '../auth/guards/jwt.guard';

@ApiTags('Wallet')
@ApiBearerAuth()
@UseGuards(JwtGuard)
@Controller('wallet')
export class WalletController {
  constructor(private readonly walletService: WalletService) {}

  @Get('balance')
  @ApiOperation({ summary: 'Lihat saldo' })
  getBalance(@Req() req: Request & { user: { userId: string } }) {
    return this.walletService.getBalance(req.user.userId);
  }

  @Post('topup')
  @ApiOperation({ summary: 'Top-up saldo (penumpang)' })
  topUp(
    @Req() req: Request & { user: { userId: string } },
    @Body() body: { amount: number },
  ) {
    return this.walletService.topUp(req.user.userId, Number(body.amount));
  }

  @Post('withdraw')
  @ApiOperation({ summary: 'Tarik saldo (driver)' })
  withdraw(
    @Req() req: Request & { user: { userId: string } },
    @Body() body: { amount: number },
  ) {
    return this.walletService.withdraw(req.user.userId, Number(body.amount));
  }

  @Get('transactions')
  @ApiOperation({ summary: 'Riwayat transaksi' })
  getTransactions(
    @Req() req: Request & { user: { userId: string } },
    @Query('limit') limit?: string,
  ) {
    return this.walletService.getTransactions(
      req.user.userId,
      limit ? Number(limit) : 20,
    );
  }
}
