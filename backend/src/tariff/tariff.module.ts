import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TariffService } from './tariff.service';
import { TariffController } from './tariff.controller';
import { TariffConfig } from './entities/tariff_config.entity';
import { TariffHistory } from './entities/tariff_history.entity';

@Module({
  imports: [TypeOrmModule.forFeature([TariffConfig, TariffHistory])],
  providers: [TariffService],
  controllers: [TariffController],
  exports: [TariffService],
})
export class TariffModule {}
