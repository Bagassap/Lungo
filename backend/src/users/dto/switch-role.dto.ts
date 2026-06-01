import { IsEnum } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { UserRole } from '../entities/user.entity';

export class SwitchRoleDto {
  @ApiProperty({ enum: UserRole })
  @IsEnum(UserRole)
  targetRole!: UserRole;
}
