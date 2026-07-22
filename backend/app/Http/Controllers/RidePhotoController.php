<?php

namespace App\Http\Controllers;

use App\Models\Ride;
use Illuminate\Http\Request;

class RidePhotoController extends Controller
{
    /**
     * Attach a photo to one of the authenticated user's own rides.
     */
    public function store(Request $request, string $rideId)
    {
        $ride = Ride::where('user_id', $request->user()->id)->findOrFail($rideId);

        $request->validate([
            'photo' => ['required', 'image', 'max:10240'],
        ]);

        $path = $request->file('photo')->store('ride-photos', 'public');

        $photo = $ride->photos()->create(['path' => $path]);

        return response()->json([
            'id' => $photo->id,
            'url' => $photo->url,
        ], 201);
    }
}
