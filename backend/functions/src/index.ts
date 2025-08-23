import { onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import axios, { isAxiosError } from "axios";

// フロントエンドに返す施設のデータ構造をinterfaceで定義
interface Facility {
    id: number;
    name: string;
    lat: number;
    lon: number;
    category: string;
}

// Overpass APIのレスポンスの要素の型を定義
interface OverpassElement {
    id: number;
    lat?: number;
    lon?: number;
    center?: {
        lat: number;
        lon: number;
    };
    tags?: {
        name?: string;
        amenity?: string;
    };
}

// Overpass APIのレスポンス全体の型を定義
interface OverpassResponse {
    elements: OverpassElement[];
}

// MLサービスから受け取る検索条件の型を定義
interface SearchTerm {
    key: string;
    value: string;
}

/**
 * Overpass APIのフィルタ部分を動的に生成する関数
 * @param terms MLサービスから受け取った検索条件オブジェクトの配列
 * @returns Overpass APIクエリのフィルタ文字列 (例: ["amenity"="restaurant"]["cuisine"="ramen"])
 */
const buildOverpassFilters = (terms: SearchTerm[]): string => {
    return terms.map((term) => `["${term.key}"="${term.value}"]`).join("");
};

export const searchFacilities = onRequest(
    { cors: true }, // CORSを有効化
    async (request, response) => {
        logger.info("Search request received", { structuredData: true });

        // クエリパラメータから緯度・経度・半径を取得
        const lat = request.query.lat as string;
        const lon = request.query.lon as string;
        const radius = (request.query.radius as string) || "1000"; // デフォルト半径1000m

        // 必須パラメータのバリデーション
        if (!lat || !lon) {
            logger.warn("Missing lat or lon parameter", {
                query: request.query,
            });
            response
                .status(400)
                .json({ error: "緯度(lat)と経度(lon)は必須です。" });
            return; // 処理を中断
        }
        if (isNaN(Number(lat)) || isNaN(Number(lon)) || isNaN(Number(radius))) {
            logger.warn("Invalid lat, lon, or radius parameter", {
                query: request.query,
            });
            response
                .status(400)
                .json({ error: "緯度、経度、半径は数値を指定してください。" });
            return;
        }

        // 検索キーワードを取得
        const keyword = request.query.keyword as string;
        if (!keyword) {
            logger.warn("Missing keyword parameter", { query: request.query });
            response
                .status(400)
                .json({ error: "検索キーワード(keyword)は必須です。" });
            return;
        }

        logger.info("Search parameters", { lat, lon, radius, keyword });

        // MLサービスを呼び出してキーワードを解析
        let searchTerms: SearchTerm[] = [];
        const mlServiceUrl = "http://127.0.0.1:8000/api/v1/analyze-keywords";

        try {
            const mlResponse = await axios.post<{ searchTerms: SearchTerm[] }>(
                mlServiceUrl,
                { query: keyword } // API仕様書通りのリクエストボディ
            );
            searchTerms = mlResponse.data.searchTerms;
            logger.info("Successfully analyzed keyword", {
                keyword,
                searchTerms,
            });
        } catch (error) {
            if (isAxiosError(error) && error.response) {
                logger.warn("ML service could not analyze keyword", {
                    keyword,
                    error: error.response.data,
                });
                response.status(200).json([]); // 解析不能でもエラーではなく「0件」として返す
            } else {
                logger.error("Failed to connect to ML service", { error });
                response.status(500).json({
                    error: "検索サービスの解析機能でエラーが発生しました。",
                });
            }
            return;
        }

        // Overpass APIのクエリを生成
        if (searchTerms.length === 0) {
            logger.info(
                "No search terms returned from ML service, returning empty array."
            );
            response.status(200).json([]);
            return;
        }
        const filters = buildOverpassFilters(searchTerms);

        const query = `
      [out:json][timeout:25];
      (
        node${filters}(around:${radius},${lat},${lon});
        way${filters}(around:${radius},${lat},${lon});
        relation${filters}(around:${radius},${lat},${lon});
      );
      out center;
    `;

        const overpassUrl = "https://overpass-api.de/api/interpreter";

        try {
            const apiResponse = await axios.post<OverpassResponse>(
                overpassUrl,
                query,
                {
                    headers: { "Content-Type": "text/plain" },
                    timeout: 15000, // 15秒でタイムアウト
                }
            );

            // Overpass APIからのレスポンス(JSON)を使いやすいように整形
            const elements: OverpassElement[] = apiResponse.data.elements;

            const facilities: Facility[] = elements
                .filter((elem) => elem.tags?.name) // nameタグがある施設のみに絞り込む
                .map((elem) => {
                    // nodeの場合は.lat/.lon、way/relationの場合は.center.lat/.lonを見る
                    const facilityLat = elem.lat ?? elem.center?.lat ?? 0;
                    const facilityLon = elem.lon ?? elem.center?.lon ?? 0;

                    return {
                        id: elem.id,
                        name: elem.tags!.name!, // filterで存在確認済み
                        lat: facilityLat,
                        lon: facilityLon,
                        category: elem.tags?.amenity ?? "unknown", // amenityタグをカテゴリとして利用
                    };
                });

            logger.info(
                `Successfully fetched and formatted ${facilities.length} facilities.`
            );
            // 整形したデータをレスポンスとして返す
            response.status(200).json(facilities);
        } catch (error) {
            // isAxiosErrorでaxiosからのエラーか判定
            if (isAxiosError(error)) {
                // タイムアウトの場合
                if (error.code === "ECONNABORTED") {
                    logger.error("Overpass API request timed out", { query });
                    response.status(504).json({
                        error: "検索サービスが時間内に応答しませんでした。少し時間を置いて再度お試しください。",
                    });
                } else if (error.response) {
                    // Overpass APIからエラーレスポンスが返ってきた場合
                    logger.error("Overpass API returned an error", {
                        status: error.response.status,
                        data: error.response.data,
                        query,
                    });
                    // フロントエンドにはステータスコードに応じてメッセージを返す
                    if (error.response.status === 429) {
                        response.status(429).json({
                            error: "検索リクエストが集中しています。しばらくしてから再度お試しください。",
                        });
                    } else {
                        response.status(502).json({
                            error: "施設情報の取得中にエラーが発生しました。",
                        });
                    }
                } else {
                    // リクエストはしたがレスポンスがない場合 (ネットワーク障害など)
                    logger.error("Network error with Overpass API", {
                        message: error.message,
                        query,
                    });
                    response.status(503).json({
                        error: "検索サービスに接続できませんでした。",
                    });
                }
            } else {
                // axios以外の予期せぬエラー (データ整形中のバグなど)
                logger.error("An unexpected error occurred", error);
                response.status(500).json({
                    error: "サーバー内部で予期せぬエラーが発生しました。",
                });
            }
        }
    }
);
