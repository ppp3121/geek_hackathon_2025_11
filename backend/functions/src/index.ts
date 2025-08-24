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
    distance: number | null;
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
        cuisine?: string;
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

interface OsrmResponse {
    code: string;
    routes: {
        distance: number; // 距離 (メートル)
        duration: number; // 時間 (秒)
    }[];
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
        const mlServiceUrl = "https://facility-search-ml-2mbtkgeqaa-uc.a.run.app/api/v1/analyze-keywords";

        try {
            const mlResponse = await axios.post<{ search_terms: SearchTerm[] }>(
                mlServiceUrl,
                { text: keyword } // API仕様書通りのリクエストボディ
            );
            searchTerms = mlResponse.data.search_terms;
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
                        category: elem.tags?.cuisine ?? elem.tags?.amenity ?? "unknown", // amenityタグをカテゴリとして利用
                        distance: null, // 距離は後でOSRM APIで計算してセットする
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

import { parse } from "csv-parse/sync";
import * as fs from "fs";
import * as path from "path";

// --- カテゴリ検索用の辞書を準備 ---
// CSVから読み込んだデータを保持するための型を定義
interface CategoryDict {
    [categoryName: string]: SearchTerm[];
}

// CSVファイルを読み込んで、カテゴリ辞書を作成する
const loadCategoryDictionary = (): CategoryDict => {
    const csvFilePath = path.join(__dirname, "..", "osm_dictionary.csv");
    const fileContent = fs.readFileSync(csvFilePath, { encoding: "utf-8" });

    // csv-parseを使ってCSVをパース
    const records = parse(fileContent, {
        columns: true, // 1行目をヘッダーとして扱う
        skip_empty_lines: true,
    });

    const dictionary: CategoryDict = {};

    type CsvRecord = {
        text: string;
        tags: string;
    };

    for (const record of records as CsvRecord[]) {
        try {
            const tagsString = record.tags.replace(/""/g, '"');
            dictionary[record.text] = JSON.parse(tagsString);
        } catch (e) {
            logger.error(`Failed to parse tags for category: ${record.text}`, e);
        }
    }

    logger.info("Category dictionary loaded successfully.");
    return dictionary;
};

// Cloud Functionsのインスタンス起動時に一度だけ辞書を読み込む
const categoryDictionary = loadCategoryDictionary();

/**
 * 複数の施設までの距離をOSRM APIで並列に計算し、施設情報に付与する関数
 * @param userLat ユーザーの緯度
 * @param userLon ユーザーの経度
 * @param facilities 距離を計算したい施設の配列
 * @returns 距離情報(distance)が付与された施設の配列
 */
const calculateDistances = async (userLat: number, userLon: number, facilities: Omit<Facility, "distance">[]): Promise<Facility[]> => {
    const osrmBaseUrl = "http://router.project-osrm.org/route/v1/driving/";

    // 各施設への距離計算リクエストをプロミスの配列として作成
    const distancePromises = facilities.map(async (facility) => {
        const coords = `${userLon},${userLat};${facility.lon},${facility.lat}`;
        const url = `${osrmBaseUrl}${coords}?overview=false`;

        try {
            const response = await axios.get<OsrmResponse>(url);
            if (response.data.code === "Ok" && response.data.routes.length > 0) {
                // 成功した場合は距離(メートル)をセット
                return {
                    ...facility,
                    distance: response.data.routes[0].distance,
                };
            }
        } catch (error) {
            logger.error(`Failed to fetch distance for facility ${facility.id}`, { url, error });
        }
        // 失敗した場合はdistanceをnullとして返す
        return {
            ...facility,
            distance: null,
        };
    });

    // Promise.allですべてのリクエストを並列実行
    return Promise.all(distancePromises);
};

export const searchByCategory = onRequest(
    { region: "us-central1" },
    async (request, response) => {
        // CORSを許可
        response.set("Access-Control-Allow-Origin", "*");
        response.set("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS, POST");
        response.set("Access-Control-Allow-Headers", "Content-Type");

        if (request.method === "OPTIONS") {
            response.status(204).send("");
            return;
        }

        logger.info("Category search request received!");

        // --- 1. リクエストからパラメータを取得・バリデーション ---
        const lat = parseFloat(request.query.lat as string);
        const lon = parseFloat(request.query.lon as string);
        const radius = parseInt(request.query.radius as string) || 1000;
        const categoriesQuery = request.query.categories as string;

        if (isNaN(lat) || isNaN(lon)) {
            response.status(400).json({ error: "緯度(lat)と経度(lon)は必須です。" });
            return;
        }
        if (!categoriesQuery) {
            response.status(400).json({ error: "カテゴリ(categories)は必須です。" });
            return;
        }

        // カンマ区切りのカテゴリ名を配列に変換
        const selectedCategories = categoriesQuery.split(',');

        try {
            // --- 2. 各カテゴリに対応する検索条件を辞書から取得 ---
            const allSearchTerms: SearchTerm[][] = [];
            for (const category of selectedCategories) {
                if (categoryDictionary[category]) {
                    allSearchTerms.push(categoryDictionary[category]);
                }
            }

            if (allSearchTerms.length === 0) {
                response.status(200).json([]); // 有効なカテゴリが一つもなければ空の配列を返す
                return;
            }

            // --- 3. 複数カテゴリをOR検索するためのOverpassクエリを生成 ---
            const searchBlocks = allSearchTerms.map(terms => {
                const filters = terms.map(term => `["${term.key}"="${term.value}"]`).join("");
                return `
          node(around:${radius},${lat},${lon})${filters};
          way(around:${radius},${lat},${lon})${filters};
          relation(around:${radius},${lat},${lon})${filters};
        `;
            }).join("\n");

            const overpassQuery = `
        [out:json][timeout:25];
        (
          ${searchBlocks}
        );
        out center;
      `;

            // --- 4. Overpass APIを呼び出し、結果を整形して返す ---
            const overpassUrl = "https://overpass-api.de/api/interpreter";
            const overpassResponse = await axios.post(overpassUrl, overpassQuery, {
                headers: { "Content-Type": "text/plain" },
            });

            // Facility型は、searchFacilities関数で使っているものを再利用
            const facilitiesFromOverpass: Omit<Facility, "distance">[] = overpassResponse.data.elements
                .filter((element: OverpassElement): element is OverpassElement & { tags: { name: string } } =>
                    !!element.tags?.name && (!!element.lat || !!element.center)
                )
                .map((element: OverpassElement): Omit<Facility, "distance"> => {
                    const tags = element.tags || {};
                    return {
                        id: element.id,
                        lat: element.center?.lat ?? element.lat!,
                        lon: element.center?.lon ?? element.lon!,
                        name: tags.name || "名称未設定",
                        category: tags.cuisine || tags.amenity || "その他",
                    };
                });

            if (facilitiesFromOverpass.length === 0) {
                response.status(200).json([]);
                return;
            }

            const facilitiesWithDistance = await calculateDistances(lat, lon, facilitiesFromOverpass);

            facilitiesWithDistance.sort((a, b) => {
                if (a.distance === null) return 1;
                if (b.distance === null) return -1;
                return a.distance - b.distance;
            });

            response.status(200).json(facilitiesWithDistance);

        } catch (error) {
            if (isAxiosError(error)) {
                logger.error("Axios error in searchByCategory:", {
                    message: error.message,
                    code: error.code,
                    response: error.response?.data,
                });
            } else {
                logger.error("An unexpected error occurred in searchByCategory:", error);
            }
            response.status(500).json({ error: "サーバー処理中にエラーが発生しました。" });
        }
    }
);