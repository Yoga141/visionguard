<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/** POST /ai/advice — DOCS_SPEC §8.9 (Gemini di-mock dengan Http::fake). */
class AiAdviceTest extends TestCase
{
    use RefreshDatabase;

    private const GEMINI_URL = 'generativelanguage.googleapis.com/*';

    protected function setUp(): void
    {
        parent::setUp();
        config([
            'services.gemini.key' => 'kunci-uji',
            'services.gemini.model' => 'gemini-2.0-flash',
            'visionguard.ai_advice.max_per_hour' => 3,
        ]);
    }

    private function fakeGemini(string $text = '• Kedipkan mata perlahan 10 kali.'): void
    {
        Http::fake([
            self::GEMINI_URL => Http::response([
                'candidates' => [['content' => ['parts' => [['text' => $text]]]]],
            ]),
        ]);
    }

    private function metrics(array $overrides = []): array
    {
        return array_merge([
            'fatigue_score' => 45,
            'blink_rate' => 9.5,
            'perclos' => 0.08,
            'distance_cm' => 42,
            'screen_minutes' => 35,
        ], $overrides);
    }

    public function test_returns_advice_and_sends_only_summary_numbers(): void
    {
        $this->fakeGemini();
        [$user] = $this->loginUser(['name' => 'Nama Rahasia', 'email' => 'rahasia@contoh.id']);

        $this->postJson('/api/ai/advice', $this->metrics(['email' => 'bocor@contoh.id', 'image' => 'base64...']))
            ->assertOk()
            ->assertExactJson(['advice' => '• Kedipkan mata perlahan 10 kali.']);

        Http::assertSentCount(1);
        Http::assertSent(function (Request $request) use ($user) {
            $body = json_encode($request->data(), JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);

            return str_contains($request->url(), 'models/gemini-2.0-flash:generateContent')
                && $request->hasHeader('x-goog-api-key', 'kunci-uji')
                && str_contains($body, 'Skor kelelahan: 45 / 100 (Waspada)')
                && str_contains($body, 'Frekuensi kedipan: 9.5 kali/menit')
                && str_contains($body, 'PERCLOS: 8.0%')
                && ! str_contains($body, 'rahasia@contoh.id')
                && ! str_contains($body, 'Nama Rahasia')
                && ! str_contains($body, 'bocor@contoh.id')
                && ! str_contains($body, 'base64')
                && ! str_contains($body, '"user_id"')
                && ! str_contains($body, (string) $user->email);
        });
    }

    public function test_only_fatigue_score_is_required(): void
    {
        $this->fakeGemini();
        $this->loginUser();

        $this->postJson('/api/ai/advice', ['fatigue_score' => 70])->assertOk()->assertJsonStructure(['advice']);

        Http::assertSent(function (Request $r) {
            $prompt = $r->data()['contents'][0]['parts'][0]['text'];

            return str_contains($prompt, 'Skor kelelahan: 70 / 100 (Lelah)') && ! str_contains($prompt, 'PERCLOS');
        });
    }

    public function test_invalid_metrics_return_422(): void
    {
        $this->fakeGemini();
        $this->loginUser();

        $this->postJson('/api/ai/advice', $this->metrics(['fatigue_score' => 150, 'perclos' => 2]))
            ->assertStatus(422)
            ->assertJsonValidationErrors(['fatigue_score', 'perclos']);
        $this->postJson('/api/ai/advice', [])->assertStatus(422)->assertJsonValidationErrors(['fatigue_score']);

        Http::assertNothingSent();
    }

    public function test_requires_token(): void
    {
        $this->fakeGemini();

        $this->postJson('/api/ai/advice', $this->metrics())->assertUnauthorized();
        Http::assertNothingSent();
    }

    public function test_returns_503_when_key_missing_or_gemini_fails(): void
    {
        $this->loginUser();

        config(['services.gemini.key' => '']);
        Http::fake();
        $this->postJson('/api/ai/advice', $this->metrics())->assertStatus(503)->assertJsonStructure(['message']);
        Http::assertNothingSent();

        config(['services.gemini.key' => 'kunci-uji']);
        Http::fake([self::GEMINI_URL => Http::response(['error' => 'boom'], 500)]);
        $this->postJson('/api/ai/advice', $this->metrics())->assertStatus(503);
    }

    public function test_rate_limited_per_user(): void
    {
        $this->fakeGemini();
        $this->loginUser();

        for ($i = 0; $i < 3; $i++) {
            $this->postJson('/api/ai/advice', $this->metrics())->assertOk();
        }
        $this->postJson('/api/ai/advice', $this->metrics())
            ->assertStatus(429)
            ->assertJsonPath('message', 'Batas pemakaian Saran AI tercapai. Coba lagi nanti.');

        // Pengguna lain punya jatah sendiri.
        $this->resetAuth();
        $this->loginUser();
        $this->postJson('/api/ai/advice', $this->metrics())->assertOk();

        // Setelah satu jam jatah pulih.
        $this->travel(61)->minutes();
        $this->postJson('/api/ai/advice', $this->metrics())->assertOk();
    }
}
