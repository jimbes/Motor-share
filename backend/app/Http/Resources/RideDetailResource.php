<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class RideDetailResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'title' => $this->title,
            'description' => $this->description,
            'started_at' => $this->started_at,
            'duration_seconds' => $this->duration_seconds,
            'distance_meters' => $this->distance_meters,
            'avg_speed_kmh' => $this->avg_speed_kmh,
            'max_speed_kmh' => $this->max_speed_kmh,
            'track' => $this->track,
            'user' => [
                'id' => $this->user->id,
                'name' => $this->user->name,
            ],
            'bike' => $this->bike ? [
                'id' => $this->bike->id,
                'brand' => $this->bike->brand,
                'model' => $this->bike->model,
                'nickname' => $this->bike->nickname,
            ] : null,
            'photos' => $this->photos->map(fn ($photo) => [
                'id' => $photo->id,
                'url' => $photo->url,
            ]),
            'comments' => $this->comments->map(fn ($comment) => [
                'id' => $comment->id,
                'body' => $comment->body,
                'created_at' => $comment->created_at,
                'user' => [
                    'id' => $comment->user->id,
                    'name' => $comment->user->name,
                ],
            ]),
            'likes_count' => (int) ($this->likes_count ?? $this->likes->count()),
            'comments_count' => (int) ($this->comments_count ?? $this->comments->count()),
            'liked_by_me' => (bool) ($this->liked_by_me ?? $this->likes->contains('user_id', $request->user()->id)),
        ];
    }
}
