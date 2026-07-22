<?php

namespace Database\Factories;

use App\Models\Ride;
use App\Models\RidePhoto;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<RidePhoto>
 */
class RidePhotoFactory extends Factory
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
            'path' => 'ride-photos/'.fake()->uuid().'.jpg',
        ];
    }
}
