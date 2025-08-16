import { onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import axios from "axios";

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

export const searchFacilities = onRequest(
  // v2では引数に型指定が不要なことが多い
  async (request, response) => {
    logger.info("Search request received", { structuredData: true });

    // クエリパラメータから緯度・経度・半径を取得
    const lat = request.query.lat as string;
    const lon = request.query.lon as string;
    const radius = (request.query.radius as string) || "1000"; // デフォルト半径1000m

    // "amenities" パラメータを受け取る。指定がなければデフォルト値を設定
    const amenitiesQuery = (request.query.amenities as string) || "restaurant,cafe,convenience";
    const amenityList = amenitiesQuery.split(',');

    logger.info("Search parameters", { lat, lon, radius, amenities: amenityList });

    // パラメータのバリデーション
    if (!lat || !lon) {
      logger.warn("Missing lat or lon parameter", { query: request.query });
      response.status(400).json({ error: "緯度(lat)と経度(lon)は必須です。" });
      return; // 処理を中断
    }
    if (isNaN(Number(lat)) || isNaN(Number(lon)) || isNaN(Number(radius))) {
      logger.warn("Invalid lat, lon, or radius parameter", { query: request.query });
      response.status(400).json({ error: "緯度、経度、半径は数値を指定してください。" });
      return;
    }

    // amenityList配列を元に、Overpassクエリの検索部分を動的に生成
    const searchStatements = amenityList.map(amenity => `
      node["amenity"="${amenity.trim()}"](around:${radius},${lat},${lon});
      way["amenity"="${amenity.trim()}"](around:${radius},${lat},${lon});
      relation["amenity"="${amenity.trim()}"](around:${radius},${lat},${lon});
    `).join('');

    // 生成した検索部分をクエリに埋め込む
    const query = `
      [out:json];
      (
        ${searchStatements}
      );
      out center;
    `;

    const overpassUrl = "https://overpass-api.de/api/interpreter";

    try {
      const apiResponse = await axios.post<OverpassResponse>(overpassUrl, query, {
        headers: { "Content-Type": "text/plain" },
      });

      // Overpass APIからのレスポンス(JSON)を使いやすいように整形
      const elements: OverpassElement[] = apiResponse.data.elements;

      const facilities: Facility[] = elements
        .filter(elem => elem.tags?.name) // nameタグがある施設のみに絞り込む
        .map(elem => {
          // nodeの場合は.lat/.lon、way/relationの場合は.center.lat/.lonを見る
          const facilityLat = elem.lat ?? elem.center?.lat ?? 0;
          const facilityLon = elem.lon ?? elem.center?.lon ?? 0;

          return {
            id: elem.id,
            name: elem.tags!.name!, // filterで存在確認済み
            lat: facilityLat,
            lon: facilityLon,
            category: elem.tags?.amenity ?? 'unknown', // amenityタグをカテゴリとして利用
          };
        });

      logger.info(`Successfully fetched and formatted ${facilities.length} facilities.`);
      // 整形したデータをレスポンスとして返す
      response.status(200).json(facilities);

    } catch (error) {
      logger.error("Overpass API error:", error);
      response.status(500).send("Error fetching data from Overpass API.");
    }
  }
);