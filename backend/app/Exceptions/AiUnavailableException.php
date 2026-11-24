<?php

namespace App\Exceptions;

use RuntimeException;

/** Gemini tidak tersedia/gagal → 503 (DOCS_SPEC §8.9 & §11.2). */
class AiUnavailableException extends RuntimeException {}
