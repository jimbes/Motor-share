<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\Storage;

#[Fillable(['path'])]
class RidePhoto extends Model
{
    /** @use HasFactory<\Database\Factories\RidePhotoFactory> */
    use HasFactory;

    protected function url(): \Illuminate\Database\Eloquent\Casts\Attribute
    {
        return \Illuminate\Database\Eloquent\Casts\Attribute::get(
            fn () => Storage::disk('public')->url($this->path)
        );
    }

    protected $appends = ['url'];

    public function ride(): BelongsTo
    {
        return $this->belongsTo(Ride::class);
    }
}
