import { IsString, IsNotEmpty, Matches } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class SendOtpDto {
  @ApiProperty({ example: '08123456789' })
  @Matches(/^(\+62|62|0)[0-9]{9,12}$/, {
    message: 'Format nomor HP tidak valid. Contoh: 08123456789 atau 628123456789',
  })
  @IsString()
  @IsNotEmpty()
  phone: string;
}
