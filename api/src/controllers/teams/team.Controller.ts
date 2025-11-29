import { Request, Response } from 'express';
import Team from '../../models/teams.model';
import axios from 'axios';
import { ENV } from '../../utils/environments';

/**
 * @openapi
 * components:
 *   schemas:
 *     Team:
 *       type: object
 *       properties:
 *         teamId:
 *           type: number
 *         name:
 *           type: string
 *         logo:
 *           type: string
 *         leagueId:
 *           type: number
 *         season:
 *           type: number
 *         stats:
 *           type: object
 *     TeamScore:
 *       type: object
 *       properties:
 *         teamId:
 *           type: number
 *         name:
 *           type: string
 *         score:
 *           type: number
 */

const englishLeagueConfig = {
	countryId: 10,
	leagueIdv2: 7293,
	leagueIdv3: 39,
};

const englishLeagueTeams = [
	{ id: 33, name: 'Manchester United' },
	{ id: 50, name: 'Manchester City' },
	{ id: 49, name: 'Chelsea' },
	{ id: 40, name: 'Liverpool' },
	{ id: 42, name: 'Arsenal' },
	{ id: 47, name: 'Tottenham Hotspur' },
	{ id: 45, name: 'Everton' },
	{ id: 48, name: 'West Ham United' },
	{ id: 34, name: 'Newcastle United' },
];

// Helper: compute score out of 100 based on a basic algorithm
function computeTeamScoreFromStats(stats: any) {
	if (!stats) return 0;

	// try to extract useful fields
	const played =
		stats?.fixtures?.played?.total ||
		stats?.fixtures?.played ||
		stats?.fixtures?.played?.total ||
		0;
	const wins = stats?.fixtures?.wins?.total || 0;
	const draws = stats?.fixtures?.draws?.total || 0;
	const loses = stats?.fixtures?.loses?.total || 0;
	const goalsFor = stats?.goals?.for?.total || 0;
	const goalsAgainst = stats?.goals?.against?.total || 0;
	const cleanSheet = stats?.clean_sheet?.total || 0;
	const form = stats?.form || '';

	// Win rate contribution (0-50)
	const winRate = played > 0 ? wins / played : 0;
	const winScore = Math.min(Math.max(winRate, 0), 1) * 50;

	// Goal difference per match normalized to [-2, 2] -> [0,1], contribution (0-20)
	const gdPerMatch = played > 0 ? (goalsFor - goalsAgainst) / played : 0;
	const gdNormalized = Math.min(Math.max((gdPerMatch + 2) / 4, 0), 1);
	const gdScore = gdNormalized * 20;

	// Clean sheet contribution (0-20)
	const cleanSheetRate = played > 0 ? cleanSheet / played : 0;
	const cleanScore = Math.min(Math.max(cleanSheetRate, 0), 1) * 20;

	// Recent form: parse last 10 matches; W=3, D=1, L=0. Max points for 10 matches = 30.
	let formScore = 0;
	if (form && typeof form === 'string') {
		const recent = form.slice(-10).split('').reverse();
		let points = 0;
		recent.forEach((r) => {
			if (r.toUpperCase() === 'W') points += 3;
			else if (r.toUpperCase() === 'D') points += 1;
			// else 0
		});
		formScore = Math.min(points / 30, 1) * 10; // contribute 0-10
	}

	const rawScore = winScore + gdScore + cleanScore + formScore;
	return Math.min(100, Math.round(rawScore));
}

// Controller: get all teams
/**
 * @openapi
 * /api/v1/teams:
 *   get:
 *     summary: List all teams
 *     tags: [Teams]
 *     description: Returns all teams stored in the database. If none are stored, returns a default minimal set of English teams.
 *     responses:
 *       200:
 *         description: List of teams
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 results:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       teamId:
 *                         type: number
 *                       name:
 *                         type: string
 *                       logo:
 *                         type: string
 */
export async function getAllTeams(req: Request, res: Response) {
	try {
		const teams = await Team.find().lean();
		if (!teams || teams.length === 0) {
			// fallback to englishLeagueTeams
			return res.status(200).json({ results: englishLeagueTeams });
		}
		return res.status(200).json({ results: teams });
	} catch (err) {
		console.error('Get all teams failed', err);
		return res.status(500).json({ message: 'Internal server error' });
	}
}
/**
 * @openapi
 * /api/v1/teams:
 *   post:
 *     summary: Create or update a team
 *     tags: [Teams]
 *     description: Insert or update a team record. The request body should contain the `teamId` and optionally the `name`, `logo`, `leagueId`, `season` and `stats` object returned from the external API.
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               teamId:
 *                 type: number
 *               name:
 *                 type: string
 *               logo:
 *                 type: string
 *               leagueId:
 *                 type: number
 *               season:
 *                 type: number
 *               stats:
 *                 type: object
 *     responses:
 *       200:
 *         description: The upserted team
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 results:
 *                   $ref: '#/components/schemas/Team'
 */

// Controller: get a single team by teamId
/**
 * @openapi
 * /api/v1/teams/{teamId}:
 *   get:
 *     summary: Get single team information
 *     tags: [Teams]
 *     description: Returns a single team record for the given `teamId`. Falls back to a default list if not stored.
 *     parameters:
 *       - in: path
 *         name: teamId
 *         required: true
 *         schema:
 *           type: number
 *         description: Numeric ID of the team
 *       - in: query
 *         name: season
 *         required: false
 *         schema:
 *           type: number
 *         description: Season year to query statistics for (default 2023)
 *     responses:
 *       200:
 *         description: Team found
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 results:
 *                   $ref: '#/components/schemas/Team'
 *       404:
 *         description: Team not found
 */
export async function getTeam(req: Request, res: Response) {
	const { teamId } = req.params;
	if (!teamId) return res.status(400).json({ message: 'teamId parameter required' });
	try {
		const id = Number(teamId);
		const team = await Team.findOne({ teamId: id }).lean();
		if (!team) {
			// fallback to englishLeagueTeams
			const fallback = englishLeagueTeams.find((t) => t.id === id);
			if (!fallback)
				return res
					.status(404)
					.json({ message: 'Team not found', availableTeams: englishLeagueTeams });
			return res.status(200).json({ results: fallback, availableTeams: englishLeagueTeams });
		}
		return res.status(200).json({ results: team });
	} catch (err) {
		console.error('Get team failed', err);
		return res.status(500).json({ message: 'Internal server error' });
	}
}

// Controller: compute score for a team
/**
 * @openapi
 * /api/v1/teams/{teamId}/score:
 *   get:
 *     summary: Compute a team's performance score
 *     tags: [Teams]
 *     description: Returns a score (0-100) computed from the stored team stats. If stats are not stored, returns an informative response.
 *     parameters:
 *       - in: path
 *         name: teamId
 *         required: true
 *         schema:
 *           type: number
 *         description: Numeric ID of the team
 *     responses:
 *       200:
 *         description: Score returned
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 teamId:
 *                   type: number
 *                 score:
 *                   type: number
 *                 details:
 *                   type: string
 */
export async function getTeamScore(req: Request, res: Response) {
	const { teamId } = req.params;
	if (!teamId) return res.status(400).json({ message: 'teamId parameter required' });
	try {
		const id = Number(teamId);
		const team = await Team.findOne({ teamId: id }).lean();
		let stats = team?.stats;
		// If the team does not exist or has no stats in the DB, fetch from external API and store it.
		if (!stats) {
			const season = Number(req.query.season) || 2023;
			const leagueId = englishLeagueConfig.leagueIdv3;
			const url = `https://v3.football.api-sports.io/teams/statistics?league=${leagueId}&season=${season}&team=${id}`;
			try {
				const { data } = await axios.get(url, {
					headers: {
						'x-apisports-key': ENV.FOOTBALL_DATA_API_KEY,
						'x-rapidapi-key': ENV.FOOTBALL_DATA_API_KEY,
						'x-rapidapi-host': 'v3.football.api-sports.io',
					},
					timeout: 10_000,
				});

				// On API-Sports a `response` field typically contains the statistics; fall back to `data` if not.
				const apiStats = data?.response || data?.statistics || data;
				// store the team with the returned stats
				const teamInfo = data?.response?.team || apiStats?.team || { id, name: 'Unknown' };
				const upsertPayload = {
					teamId: Number(teamInfo?.id ?? id),
					name: teamInfo?.name || teamInfo?.fullName || teamInfo?.shortName || 'Unknown',
					logo: teamInfo?.logo || '',
					leagueId: leagueId,
					season,
					stats: apiStats,
				};
				// Save to DB
				await Team.findOneAndUpdate({ teamId: upsertPayload.teamId }, upsertPayload, {
					upsert: true,
					new: true,
					setDefaultsOnInsert: true,
				});
				stats = apiStats;
			} catch (err) {
				console.error(
					'Fetch team stats from external API failed',
					(err as any)?.message || err
				);
				// Can't get stats; if the team existed but had no stats, fail gracefully.
				if (!team) {
					// fallback to englishLeagueTeams list
					const fallback = englishLeagueTeams.find((t) => t.id === id);
					if (!fallback) return res.status(404).json({ message: 'Team not found' });
					return res
						.status(200)
						.json({
							teamId: id,
							score: 0,
							details: 'No stats available; returned fallback team list',
						});
				}
			}
		}
		// If we don't have stats in DB, return a heuristic score based on fallback team (no stats -> 50)
		if (!stats) {
			return res.status(200).json({ teamId: id, score: 0, details: 'No stats available' });
		}
		const score = computeTeamScoreFromStats(stats);
		return res.status(200).json({ teamId: id, score });
	} catch (err) {
		console.error('Get team score failed', err);
		return res.status(500).json({ message: 'Internal server error' });
	}
}

// Controller: compute and return scores for all teams
/**
 * @openapi
 * /api/v1/teams/scores:
 *   get:
 *     summary: Get performance scores for all teams
 *     tags: [Teams]
 *     description: Returns the computed scores (0-100) for all stored teams.
 *     responses:
 *       200:
 *         description: Scores for all teams
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 results:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       teamId:
 *                         type: number
 *                       name:
 *                         type: string
 *                       score:
 *                         type: number
 */
export async function getAllScores(req: Request, res: Response) {
	try {
		const teams = await Team.find().lean();
		const results = (teams || []).map((t) => ({
			teamId: t.teamId,
			name: t.name,
			score: computeTeamScoreFromStats(t.stats),
		}));
		return res.status(200).json({ results });
	} catch (err) {
		console.error('Get all scores failed', err);
		return res.status(500).json({ message: 'Internal server error' });
	}
}

// Controller: create or update team (store API response)
export async function upsertTeam(req: Request, res: Response) {
	try {
		const payload = req.body;
		if (!payload || !payload.teamId)
			return res.status(400).json({ message: 'teamId required' });
		const filter = { teamId: Number(payload.teamId) };
		const update = {
			teamId: Number(payload.teamId),
			name: payload.name || payload.team?.name || 'Unknown',
			logo: payload.logo || payload.team?.logo || '',
			leagueId: payload.leagueId || payload.league?.id || undefined,
			season: payload.season || undefined,
			stats: payload.stats || payload.response || {},
		};
		const team = await Team.findOneAndUpdate(filter, update, {
			upsert: true,
			new: true,
			setDefaultsOnInsert: true,
		});
		return res.status(200).json({ results: team });
	} catch (err) {
		console.error('Upsert team failed', err);
		return res.status(500).json({ message: 'Internal server error' });
	}
}
