<?php

namespace Database\Factories;

use App\Models\Ride;
use App\Models\RideLike;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<RideLike>
 */
class RideLikeFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'ride_id' => Ride::factory(),
            'user_id' => User::factory(),
        ];
    }
}
