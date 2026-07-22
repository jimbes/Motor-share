<?php

namespace Tests\Feature;

use App\Models\Ride;
use App\Models\RideComment;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class RideSocialTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_user_can_attach_a_photo_to_their_own_ride(): void
    {
        Storage::fake('public');
        $user = User::factory()->create();
        $ride = Ride::factory()->for($user)->create();

        $response = $this->actingAs($user)->postJson("/api/rides/{$ride->id}/photos", [
            'photo' => UploadedFile::fake()->image('sunset.jpg'),
        ]);

        $response->assertCreated()->assertJsonStructure(['id', 'url']);
        $this->assertDatabaseHas('ride_photos', ['ride_id' => $ride->id]);
        Storage::disk('public')->assertExists($ride->photos()->first()->path);
    }

    public function test_a_user_cannot_attach_a_photo_to_another_users_ride(): void
    {
        Storage::fake('public');
        $user = User::factory()->create();
        $other = User::factory()->create();
        $ride = Ride::factory()->for($other)->create();

        $response = $this->actingAs($user)->postJson("/api/rides/{$ride->id}/photos", [
            'photo' => UploadedFile::fake()->image('sunset.jpg'),
        ]);

        $response->assertNotFound();
    }

    public function test_a_user_can_like_a_ride(): void
    {
        $user = User::factory()->create();
        $ride = Ride::factory()->create();

        $response = $this->actingAs($user)->postJson("/api/rides/{$ride->id}/like");

        $response->assertOk()->assertJson(['likes_count' => 1, 'liked_by_me' => true]);
        $this->assertDatabaseHas('ride_likes', ['ride_id' => $ride->id, 'user_id' => $user->id]);
    }

    public function test_liking_a_ride_twice_does_not_duplicate_the_like(): void
    {
        $user = User::factory()->create();
        $ride = Ride::factory()->create();

        $this->actingAs($user)->postJson("/api/rides/{$ride->id}/like");
        $response = $this->actingAs($user)->postJson("/api/rides/{$ride->id}/like");

        $response->assertJson(['likes_count' => 1]);
        $this->assertEquals(1, $ride->likes()->count());
    }

    public function test_a_user_can_unlike_a_ride(): void
    {
        $user = User::factory()->create();
        $ride = Ride::factory()->create();
        $ride->likes()->create(['user_id' => $user->id]);

        $response = $this->actingAs($user)->deleteJson("/api/rides/{$ride->id}/like");

        $response->assertOk()->assertJson(['likes_count' => 0, 'liked_by_me' => false]);
        $this->assertDatabaseMissing('ride_likes', ['ride_id' => $ride->id, 'user_id' => $user->id]);
    }

    public function test_a_user_can_comment_on_a_ride(): void
    {
        $user = User::factory()->create();
        $ride = Ride::factory()->create();

        $response = $this->actingAs($user)->postJson("/api/rides/{$ride->id}/comments", [
            'body' => 'Great line through that last corner!',
        ]);

        $response->assertCreated()->assertJsonFragment(['body' => 'Great line through that last corner!']);
        $this->assertDatabaseHas('ride_comments', ['ride_id' => $ride->id, 'user_id' => $user->id]);
    }

    public function test_comments_require_a_body(): void
    {
        $user = User::factory()->create();
        $ride = Ride::factory()->create();

        $response = $this->actingAs($user)->postJson("/api/rides/{$ride->id}/comments", ['body' => '']);

        $response->assertUnprocessable()->assertJsonValidationErrors('body');
    }

    public function test_a_user_can_delete_their_own_comment(): void
    {
        $user = User::factory()->create();
        $ride = Ride::factory()->create();
        $comment = RideComment::factory()->for($ride)->for($user)->create();

        $response = $this->actingAs($user)->deleteJson("/api/comments/{$comment->id}");

        $response->assertNoContent();
        $this->assertDatabaseMissing('ride_comments', ['id' => $comment->id]);
    }

    public function test_a_user_cannot_delete_another_users_comment(): void
    {
        $user = User::factory()->create();
        $other = User::factory()->create();
        $ride = Ride::factory()->create();
        $comment = RideComment::factory()->for($ride)->for($other)->create();

        $response = $this->actingAs($user)->deleteJson("/api/comments/{$comment->id}");

        $response->assertNotFound();
        $this->assertDatabaseHas('ride_comments', ['id' => $comment->id]);
    }
}
