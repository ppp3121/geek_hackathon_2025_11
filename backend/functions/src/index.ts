import { onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import axios from "axios";

export const searchFacilities = onRequest(
  // v2では引数に型指定が不要なことが多いらしい
  async (request, response) => {
    logger.info("Search request received", { structuredData: true });

    const lat = 35.681236;
    const lon = 139.767125;

    const query = `
      [out:json];
      (
        node["amenity"="cafe"](around:1000, ${lat}, ${lon});
        way["amenity"="cafe"](around:1000, ${lat}, ${lon});
        relation["amenity"="cafe"](around:1000, ${lat}, ${lon});
      );
      out center;
    `;

    const overpassUrl = "https://overpass-api.de/api/interpreter";

    try {
      const apiResponse = await axios.post(overpassUrl, query, {
        headers: { "Content-Type": "text/plain" },
      });

      logger.info("Successfully fetched data from Overpass API");
      response.status(200).send(apiResponse.data);

    } catch (error) {
      logger.error("Overpass API error:", error);
      response.status(500).send("Error fetching data from Overpass API.");
    }
  }
);