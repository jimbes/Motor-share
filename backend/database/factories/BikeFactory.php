<?php

namespace Database\Factories;

use App\Models\Bike;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Bike>
 */
class BikeFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'brand' => fake()->randomElement(['Yamaha', 'Honda', 'Ducati', 'KTM', 'BMW']),
            'model' => fake()->bothify('??-###'),
            'year' => fake()->numberBetween(2000, 2026),
            'nickname' => fake()->firstName(),
            'engine_cc' => fake()->randomElement([125, 300, 600, 750, 900, 1000, 1200]),
        ];
    }
}
