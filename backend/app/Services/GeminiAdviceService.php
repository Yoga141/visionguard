<?php

namespace App\Services;

use App\Exceptions\AiUnavailableException;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;

/**
 * Saran AI lewat Gemini — DOCS_SPEC §17.4.
 *
 * - Yang dikirim ke Gemini **hanya angka ringkasan** §17.2 (tanpa nama, email,
 *   ID pengguna, gambar, landmark).
 * - API key hanya di `backend/.env` (`GEMINI_API_KEY`).
 * - Prompt dan respons **tidak disimpan/di-log**.
 */
class GeminiAdviceService
{
    public const SYSTEM_PROMPT = 'Kamu adalah asisten kesehatan mata bernama VisionGuard AI. '
        .'Tugasmu memberi saran singkat, praktis, dan ramah dalam Bahasa Indonesia '
        .'untuk menjaga kesehatan mata pengguna saat bekerja di depan layar. '
        .'Jangan memberi diagnosis medis, cukup saran umum pencegahan kelelahan mata digital.';

    /**
     * @param  array{fatigue_score: int, blink_rate?: ?float, perclos?: ?float, distance_cm?: ?float, screen_minutes?: ?int}  $metrics
     *
     * @throws AiUnavailableException
     */
    public function advise(array $metrics): string
    {
        $key = (string) config('services.gemini.key');
        if ($key === '') {
            throw new AiUnavailableException('Layanan AI belum dikonfigurasi.');
        }

        $url = rtrim((string) config('services.gemini.base_url'), '/')
            .'/models/'.config('services.gemini.model').':generateContent';

        try {
            $response = Http::withHeaders(['x-goog-api-key' => $key])
                ->acceptJson()
                ->timeout((int) config('services.gemini.timeout'))
                ->post($url, [
                    'systemInstruction' => ['parts' => [['text' => self::SYSTEM_PROMPT]]],
                    'contents' => [['role' => 'user', 'parts' => [['text' => self::buildPrompt($metrics)]]]],
                    'generationConfig' => ['temperature' => 0.7, 'maxOutputTokens' => 512],
                ]);
        } catch (ConnectionException) {
            throw new AiUnavailableException('Layanan AI tidak dapat dihubungi.');
        }

        if (! $response->successful()) {
            throw new AiUnavailableException('Layanan AI sedang tidak tersedia.');
        }

        $text = collect($response->json('candidates.0.content.parts', []))
            ->pluck('text')
            ->filter(fn ($t) => is_string($t))
            ->implode('');

        if (trim($text) === '') {
            throw new AiUnavailableException('Layanan AI tidak memberi jawaban.');
        }

        return trim($text);
    }

    /** Prompt hanya berisi angka ringkasan (sama dengan klien `buildPrompt`). */
    public static function buildPrompt(array $metrics): string
    {
        $score = (int) $metrics['fatigue_score'];
        $lines = [
            'Berikut data kondisi mata pengguna saat ini:',
            "- Skor kelelahan: {$score} / 100 (".self::levelLabel($score).')',
        ];

        if (isset($metrics['blink_rate'])) {
            $lines[] = '- Frekuensi kedipan: '.number_format((float) $metrics['blink_rate'], 1, '.', '').' kali/menit';
        }
        if (isset($metrics['perclos'])) {
            $lines[] = '- PERCLOS: '.number_format((float) $metrics['perclos'] * 100, 1, '.', '').'%';
        }
        if (isset($metrics['screen_minutes'])) {
            $lines[] = '- Durasi menatap layar: '.(int) $metrics['screen_minutes'].' menit';
        }
        if (isset($metrics['distance_cm'])) {
            $lines[] = '- Jarak ke layar: '.number_format((float) $metrics['distance_cm'], 0, '.', '').' cm';
        }

        $lines[] = '';
        $lines[] = 'Berdasarkan data di atas, berikan 2–3 saran singkat dan praktis '
            .'untuk menjaga kesehatan mata pengguna. Gunakan bahasa yang ramah dan mudah dipahami.';

        return implode("\n", $lines);
    }

    /** Level §9.4: 0–39 Normal, 40–59 Waspada, 60–100 Lelah. */
    public static function levelLabel(int $score): string
    {
        return match (true) {
            $score >= (int) config('visionguard.fatigue_levels.tired_min') => 'Lelah',
            $score >= (int) config('visionguard.fatigue_levels.alert_min') => 'Waspada',
            default => 'Normal',
        };
    }
}
