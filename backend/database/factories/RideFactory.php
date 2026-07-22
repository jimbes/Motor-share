<?php

namespace Database\Factories;

use App\Models\Ride;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Ride>
 */
class RideFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        $lat = fake()->latitude(43.0, 44.0);
        $lng = fake()->longitude(5.0, 6.0);
        $track = [];

        for ($i = 0; $i < 20; $i++) {
            $lat += fake()->randomFloat(5, -0.001, 0.001);
            $lng += fake()->randomFloat(5, -0.001, 0.001);
            $track[] = [
                'lat' => $lat,
                'lng' => $lng,
                'alt' => fake()->randomFloat(1, 0, 500),
                'speed' => fake()->randomFloat(1, 0, 120),
                't' => now()->addSeconds($i * 5)->toIso8601String(),
            ];
        }

        return [
            'user_id' => User::factory(),
            'bike_id' => null,
            'title' => fake()->sentence(3),
            'description' => fake()->optional()->paragraph(),
            'started_at' => fake()->dateTimeBetween('-1 month'),
            'duration_seconds' => fake()->numberBetween(300, 7200),
            'distance_meters' => fake()->numberBetween(1000, 150000),
            'avg_speed_kmh' => fake()->randomFloat(2, 20, 90),
            'max_speed_kmh' => fake()->randomFloat(2, 90, 220),
            'track' => $track,
            'polyline_simplified' => $track,
        ];
    }
}
