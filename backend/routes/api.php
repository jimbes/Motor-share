<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\BikeController;
use App\Http\Controllers\RideCommentController;
use App\Http\Controllers\RideController;
use App\Http\Controllers\RideLikeController;
use App\Http\Controllers\RidePhotoController;
use Illuminate\Support\Facades\Route;

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);

    Route::apiResource('bikes', BikeController::class)->except(['show']);
    Route::get('/bikes/{id}', [BikeController::class, 'show']);

    Route::get('/rides', [RideController::class, 'index']);
    Route::post('/rides', [RideController::class, 'store']);
    Route::get('/me/stats', [RideController::class, 'myStats']);
    Route::get('/rides/{id}', [RideController::class, 'show']);

    Route::post('/rides/{ride}/photos', [RidePhotoController::class, 'store']);

    Route::post('/rides/{ride}/like', [RideLikeController::class, 'store']);
    Route::delete('/rides/{ride}/like', [RideLikeController::class, 'destroy']);

    Route::get('/rides/{ride}/comments', [RideCommentController::class, 'index']);
    Route::post('/rides/{ride}/comments', [RideCommentController::class, 'store']);
    Route::delete('/comments/{comment}', [RideCommentController::class, 'destroy']);
});
