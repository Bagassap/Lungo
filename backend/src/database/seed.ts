import 'reflect-metadata';
import * as dotenv from 'dotenv';
import { DataSource } from 'typeorm';
import { User } from '../users/entities/user.entity';
import { Driver } from '../drivers/entities/driver.entity';
import { UserRole } from '../users/entities/user.entity';

dotenv.config({ path: `${__dirname}/../../.env` });

const AppDataSource = new DataSource({
  type: 'postgres',
  host: process.env.DB_HOST ?? 'localhost',
  port: Number(process.env.DB_PORT ?? 5432),
  username: process.env.DB_USERNAME ?? 'postgres',
  password: process.env.DB_PASSWORD ?? '',
  database: process.env.DB_NAME ?? 'lungo_db',
  entities: [User, Driver],
  synchronize: false,
  logging: false,
});

const DEMO_USERS = [
  { phone: '085640168132',  name: 'Dev Penumpang',  role: UserRole.PASSENGER, isVerified: true },
  { phone: '085640168132',  name: 'Dev Driver',     role: UserRole.DRIVER,    isVerified: true },
  { phone: '085640168132',  name: 'Dev Admin',      role: UserRole.ADMIN,     isVerified: true },
];

async function seed() {
  await AppDataSource.initialize();
  console.log('Database connected.\n');

  // ── Migration: change unique constraint from (phone) to (phone, role) ──
  console.log('Running schema migration...');
  try {
    // Find any unique constraint that covers only the phone column
    const rows: { constraint_name: string }[] = await AppDataSource.query(`
      SELECT tc.constraint_name
      FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu
        ON kcu.constraint_name = tc.constraint_name AND kcu.table_name = tc.table_name
      WHERE tc.table_name = 'users'
        AND tc.constraint_type = 'UNIQUE'
        AND kcu.column_name = 'phone'
      GROUP BY tc.constraint_name
      HAVING COUNT(*) = 1
    `);
    for (const row of rows) {
      await AppDataSource.query(`ALTER TABLE users DROP CONSTRAINT IF EXISTS "${row.constraint_name}"`);
      console.log(`  [MIGR] Dropped constraint ${row.constraint_name}`);
    }
  } catch (e: any) {
    console.log('  [MIGR] Drop skipped:', e.message);
  }
  try {
    await AppDataSource.query(
      `ALTER TABLE users ADD CONSTRAINT "UQ_users_phone_role" UNIQUE (phone, role)`,
    );
    console.log('  [MIGR] Added composite unique (phone, role)');
  } catch (e: any) {
    console.log('  [MIGR] Constraint already exists:', e.message);
  }
  console.log();

  // ── Migration: add ktpNumber column ──
  try {
    await AppDataSource.query(
      `ALTER TABLE drivers ADD COLUMN IF NOT EXISTS "ktpNumber" TEXT`,
    );
    console.log('  [MIGR] Column ktpNumber ensured');
  } catch (e: any) {
    console.log('  [MIGR] ktpNumber column:', e.message);
  }

  // ── Migration: add fcmToken column to users ──
  try {
    await AppDataSource.query(
      `ALTER TABLE users ADD COLUMN IF NOT EXISTS "fcmToken" TEXT`,
    );
    console.log('  [MIGR] Column users.fcmToken ensured');
  } catch (e: any) {
    console.log('  [MIGR] fcmToken column:', e.message);
  }

  // ── Migration: create admin_notifications table ──
  try {
    await AppDataSource.query(`
      CREATE TABLE IF NOT EXISTS admin_notifications (
        id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
        type       VARCHAR(64)  NOT NULL,
        title      VARCHAR(255) NOT NULL,
        body       TEXT         NOT NULL,
        "targetId" TEXT,
        "isRead"   BOOLEAN      NOT NULL DEFAULT FALSE,
        "createdAt" TIMESTAMP   NOT NULL DEFAULT NOW()
      )
    `);
    console.log('  [MIGR] Table admin_notifications ensured');
  } catch (e: any) {
    console.log('  [MIGR] admin_notifications:', e.message);
  }

  // ── Migration: create complaints table ──
  try {
    await AppDataSource.query(`
      DO $$ BEGIN
        CREATE TYPE complaint_type_enum AS ENUM ('COMPLAINT', 'SUGGESTION', 'PRAISE');
      EXCEPTION WHEN duplicate_object THEN NULL; END $$
    `);
    await AppDataSource.query(`
      DO $$ BEGIN
        CREATE TYPE complaint_status_enum AS ENUM ('OPEN', 'IN_REVIEW', 'RESOLVED', 'CLOSED');
      EXCEPTION WHEN duplicate_object THEN NULL; END $$
    `);
    await AppDataSource.query(`
      CREATE TABLE IF NOT EXISTS complaints (
        id            UUID                  PRIMARY KEY DEFAULT gen_random_uuid(),
        "passengerId" VARCHAR               NOT NULL,
        "driverId"    VARCHAR,
        "rideId"      VARCHAR,
        type          complaint_type_enum   NOT NULL DEFAULT 'COMPLAINT',
        subject       VARCHAR(200)          NOT NULL,
        message       TEXT                  NOT NULL,
        status        complaint_status_enum NOT NULL DEFAULT 'OPEN',
        "adminReply"  TEXT,
        "repliedBy"   VARCHAR,
        "repliedAt"   TIMESTAMP,
        "createdAt"   TIMESTAMP             NOT NULL DEFAULT NOW(),
        "updatedAt"   TIMESTAMP             NOT NULL DEFAULT NOW()
      )
    `);
    console.log('  [MIGR] Table complaints ensured');
  } catch (e: any) {
    console.log('  [MIGR] complaints:', e.message);
  }

  // ── Migration: create weekly_reports table ──
  try {
    await AppDataSource.query(`
      CREATE TABLE IF NOT EXISTS weekly_reports (
        id                UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
        "driverId"        VARCHAR       NOT NULL,
        "driverName"      VARCHAR       NOT NULL,
        "weekStart"       DATE          NOT NULL,
        "weekEnd"         DATE          NOT NULL,
        "totalRides"      INT           NOT NULL DEFAULT 0,
        "completedRides"  INT           NOT NULL DEFAULT 0,
        "cancelledRides"  INT           NOT NULL DEFAULT 0,
        "totalEarnings"   DECIMAL(14,2) NOT NULL DEFAULT 0,
        "avgRating"       DECIMAL(3,2),
        "totalDistanceKm" DECIMAL(10,3) NOT NULL DEFAULT 0,
        "dailyBreakdown"  JSONB,
        "createdAt"       TIMESTAMP     NOT NULL DEFAULT NOW()
      )
    `);
    console.log('  [MIGR] Table weekly_reports ensured');
  } catch (e: any) {
    console.log('  [MIGR] weekly_reports:', e.message);
  }

  // ── Migration: create audit_logs table ──
  try {
    await AppDataSource.query(`
      CREATE TABLE IF NOT EXISTS audit_logs (
        id           UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
        "adminId"    VARCHAR   NOT NULL,
        "adminName"  VARCHAR   NOT NULL,
        action       VARCHAR   NOT NULL,
        details      TEXT,
        "targetId"   VARCHAR,
        "targetType" VARCHAR,
        "ipAddress"  VARCHAR,
        "createdAt"  TIMESTAMP NOT NULL DEFAULT NOW()
      )
    `);
    console.log('  [MIGR] Table audit_logs ensured');
  } catch (e: any) {
    console.log('  [MIGR] audit_logs:', e.message);
  }

  // ── Migration: add driver registration columns ──
  const driverColumns: [string, string][] = [
    ['fcmToken',     'TEXT'],
    ['bpkbPhotoUrl', 'TEXT'],
    ['stnkPhotoUrl', 'TEXT'],
    ['birthPlace',   'TEXT'],
    ['birthDate',    'DATE'],
    ['address',      'TEXT'],
  ];
  for (const [col, type] of driverColumns) {
    try {
      await AppDataSource.query(
        `ALTER TABLE drivers ADD COLUMN IF NOT EXISTS "${col}" ${type}`,
      );
      console.log(`  [MIGR] Column drivers.${col} ensured`);
    } catch (e: any) {
      console.log(`  [MIGR] drivers.${col}:`, e.message);
    }
  }
  console.log();

  // ── Seed accounts ──
  console.log('Seeding demo accounts...\n');
  const userRepo = AppDataSource.getRepository(User);
  const driverRepo = AppDataSource.getRepository(Driver);

  for (const data of DEMO_USERS) {
    let user = await userRepo.findOne({ where: { phone: data.phone, role: data.role } });
    if (user) {
      await userRepo.update(user.id, { name: data.name, isVerified: data.isVerified });
      user = (await userRepo.findOne({ where: { phone: data.phone, role: data.role } }))!;
      console.log(`  [RESET] ${data.name} (${data.phone} / ${data.role})`);
    } else {
      user = userRepo.create(data);
      await userRepo.save(user);
      console.log(`  [OK]   ${data.name} (${data.phone} / ${data.role})`);
    }

    if (data.role === UserRole.DRIVER) {
      const existing = await driverRepo.findOne({ where: { userId: user.id } });
      if (!existing) {
        const driver = driverRepo.create({
          userId: user.id,
          vehiclePlate: 'D 1234 LNG',
          vehicleType: 'Motor',
          rating: 4.9,
          totalRides: 42,
          isOnline: false,
        });
        await driverRepo.save(driver);
        console.log(`  [OK]   Driver profile untuk ${data.name} dibuat`);
      }
    }
  }

  console.log('\nSeed selesai!');
  console.log('\nAkun Dev (085640168132):');
  console.log('  PASSENGER : Dev Penumpang');
  console.log('  DRIVER    : Dev Driver');
  console.log('  ADMIN     : Dev Admin');
  console.log('\nLogin: kirim OTP ke 085640168132, pilih role di app.');

  await AppDataSource.destroy();
}

seed().catch((err) => {
  console.error('Seed error:', err);
  process.exit(1);
});
