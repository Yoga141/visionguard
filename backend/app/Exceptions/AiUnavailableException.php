<?php

namespace App\Exceptions;

use RuntimeException;

/** Gemini tidak tersedia/gagal → 503 (DOCS_SPEC §17.4). */
class AiUnavailableException extends RuntimeException {}
