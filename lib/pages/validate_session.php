<?php
declare(strict_types=1);

require_once __DIR__ . '/cors.php';
require_once __DIR__ . '/db.php';

header('Content-Type: application/json; charset=UTF-8');

function respond(int $status, array $body): void
{
    http_response_code($status);
    echo json_encode($body);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    header('Allow: GET');

    respond(405, [
        'success' => false,
        'message' => 'Method tidak diizinkan.',
    ]);
}

$authorization = $_SERVER['HTTP_AUTHORIZATION'] ?? '';

if (!preg_match('/Bearer\s+(\S+)/i', $authorization, $matches)) {
    respond(401, [
        'success' => false,
        'message' => 'Token tidak ditemukan.',
    ]);
}

$token = $matches[1];
$tokenHash = hash('sha256', $token);

try {
    $sql = "
        SELECT
            u.id,
            u.username,
            u.full_name,
            u.role,
            u.is_active
        FROM api_tokens AS t
        INNER JOIN users AS u ON u.id = t.user_id
        WHERE t.token_hash = :token_hash
          AND t.expires_at > UTC_TIMESTAMP()
          AND u.is_active = 1
        LIMIT 1
    ";

    $stmt = $pdo->prepare($sql);
    $stmt->execute([
        'token_hash' => $tokenHash,
    ]);

    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        respond(401, [
            'success' => false,
            'message' => 'Token tidak valid atau kedaluwarsa.',
        ]);
    }

    $user['is_active'] = (int) $user['is_active'];

    respond(200, [
        'success' => true,
        'data' => $user,
    ]);
} catch (Throwable $e) {
    error_log(
        'validate_session error: ' . $e->getMessage()
    );

    respond(500, [
        'success' => false,
        'message' => 'Terjadi kesalahan pada server.',
    ]);
}
