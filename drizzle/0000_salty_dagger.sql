CREATE TABLE `payments` (
	`id` text PRIMARY KEY NOT NULL,
	`invoice` text NOT NULL,
	`token` text NOT NULL,
	`status` text NOT NULL,
	`created` text NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `payments_token_unique` ON `payments` (`token`);--> statement-breakpoint
CREATE TABLE `records` (
	`id` text PRIMARY KEY NOT NULL,
	`kind` text NOT NULL,
	`email` text DEFAULT '' NOT NULL,
	`data` text NOT NULL,
	`created` text NOT NULL,
	`updated` text NOT NULL
);
--> statement-breakpoint
CREATE INDEX `idx_records_kind_email` ON `records` (`kind`,`email`);