<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('rides', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('bike_id')->nullable()->constrained()->nullOnDelete();
            $table->string('title');
            $table->text('description')->nullable();
            $table->timestamp('started_at');
            $table->unsignedInteger('duration_seconds')->default(0);
            $table->unsignedInteger('distance_meters')->default(0);
            $table->decimal('avg_speed_kmh', 6, 2)->default(0);
            $table->decimal('max_speed_kmh', 6, 2)->default(0);
            $table->json('track');
            $table->json('polyline_simplified')->nullable();
            $table->timestamps();

            $table->index('started_at');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('rides');
    }
};
