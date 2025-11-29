import { Router } from 'express';
import {
	getAllTeams,
	getTeam,
	getTeamScore,
	getAllScores,
	upsertTeam,
} from '../../controllers/teams';

const router: Router = Router();

// List all teams
router.get('/', getAllTeams);

// Create or update a team's info or stats
router.post('/', upsertTeam);

// Get scores for all teams
router.get('/scores', getAllScores);

// Get score of a team (computed)
router.get('/:teamId/score', getTeamScore);

// Get a single team by its id
router.get('/:teamId', getTeam);

export default router;
